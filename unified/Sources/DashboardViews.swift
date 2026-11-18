import AppKit
import SwiftUI

enum AppIdentity {
    static let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "Development"
    static let windowTitle="HID Emu \(version) — Flipper Zero + Cardputer"
}
enum Palette {
    static let background=Color(red:0.045,green:0.058,blue:0.080)
    static let panel=Color(red:0.080,green:0.098,blue:0.131)
    static let accent=Color(red:0.39,green:0.72,blue:1.0)
    static let healthy=Color(red:0.36,green:0.83,blue:0.68)
    static let scrollDown=Color(Spectrum.down)
    static let scrollUp=Color(Spectrum.up)
    static let left=Color(Spectrum.left)
    static let right=Color(Spectrum.right)
}
struct DashboardPanel<Content:View>:View {
    let content:Content
    init(@ViewBuilder content:()->Content){self.content=content()}
    var body:some View {
        content.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(Palette.panel,in:RoundedRectangle(cornerRadius:10))
            .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(.white.opacity(0.07)))
    }
}
struct SectionCaption:View {
    let title:String
    var body:some View {Text(title).font(.system(size:11,weight:.medium)).foregroundStyle(.secondary)}
}
struct DashboardView:View {
    @ObservedObject var m:Dashboard
    @ObservedObject private var firmware=FirmwareCenter.shared
    @State private var updates=false
    @State private var settings=false
    @State private var tab="Activity"
    private var busy:Bool {m.connected || m.connecting}
    private var endpoint:String {
        if m.connected {return "\(m.deviceName) · firmware \(m.deviceVersion)"}
        if m.deviceChoice == "Cardputer" || (m.deviceChoice == "Automatic" && !m.ports.isEmpty) {return m.selectedPort.isEmpty ? "Connect Cardputer with USB":"Cardputer available over USB"}
        return m.flipperName.isEmpty ? "Set the Flipper name in connection settings":"Flipper Zero · \(m.flipperName)"
    }
    var body:some View {
        VStack(spacing:10) {
            header
            connection
            HStack(alignment:.top,spacing:10) {pointer;inputState}.frame(height:148)
            application
            console.frame(maxHeight:.infinity)
            HStack(spacing:12) {
                Text(m.connectionMessage).lineLimit(1).help(m.connectionMessage)
                Spacer(minLength:0)
                Text("⌘. Stop · 60s arm limit").fixedSize()
            }.font(.system(size:11)).foregroundStyle(.secondary).frame(height:16)
        }
        .padding(14).frame(minWidth:720,minHeight:580)
        .background(Palette.background).tint(Palette.accent).preferredColorScheme(.dark)
        .sheet(isPresented:$updates){FirmwareCenterView(center:firmware,dashboard:m)}
        .onChange(of:m.deviceVersion){if m.connected {firmware.observed(m.deviceVersion,flipper:m.isFlipper)}}
    }
    private var header:some View {
        HStack(spacing:10) {
            if let url=Bundle.main.url(forResource:"HIDEmu",withExtension:"icns"),let icon=NSImage(contentsOf:url) {
                Image(nsImage:icon).resizable().frame(width:38,height:38).accessibilityHidden(true)
            }
            VStack(alignment:.leading,spacing:3) {
                HStack(alignment:.firstTextBaseline,spacing:7) {
                    Text("HID Emu").font(.system(size:19,weight:.semibold))
                    Text(AppIdentity.version).font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(.secondary)
                }
                Text("Flipper Zero + Cardputer").font(.system(size:11)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment:.trailing,spacing:4) {
                HStack(spacing:5) {
                    Circle().fill(m.connected ? Palette.healthy:(m.connecting ? Palette.scrollDown:Color.secondary)).frame(width:6,height:6)
                    Text(m.connected ? "Connected":(m.connecting ? "Connecting":"Offline")).font(.system(size:12,weight:.medium))
                }
                Text("Session \(m.uptime)").font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary).monospacedDigit()
            }
                    Button {updates=true} label:{Image(systemName:firmware.hasUpdate ? "arrow.down.circle.fill":"arrow.down.circle").font(.system(size:17)).foregroundStyle(firmware.hasUpdate ? Palette.healthy:Palette.accent)}
                .buttonStyle(.plain).help("Device updates").accessibilityLabel("Device updates")
        }.frame(height:42)
    }
    private var connection:some View {
        DashboardPanel {
            HStack(spacing:10) {
                Picker("Device",selection:$m.deviceChoice) {
                    ForEach(["Automatic","Cardputer","Flipper Zero"],id:\.self){Text($0)}
                }.labelsHidden().frame(width:140,alignment:.leading).disabled(busy).help("Automatic prefers Cardputer when both devices are available")
                Text(endpoint).font(.system(size:12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).frame(maxWidth:.infinity,alignment:.leading).help(endpoint)
                Button {settings.toggle()} label:{Image(systemName:"slider.horizontal.3").frame(width:18)}
                    .help("Connection settings").accessibilityLabel("Connection settings")
                    .popover(isPresented:$settings,arrowEdge:.bottom){connectionSettings}
                Button(busy ? "Disconnect":"Connect") {if busy {m.disconnect()}else{m.connect()}}
                    .frame(width:86).controlSize(.regular)
            }
        }
    }
    private var connectionSettings:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Connection settings").font(.headline)
            VStack(alignment:.leading,spacing:6) {
                Text("Flipper Bluetooth name").font(.system(size:12,weight:.medium))
                TextField("Name shown on your Flipper",text:$m.flipperName).textFieldStyle(.roundedBorder).disabled(busy)
            }
            VStack(alignment:.leading,spacing:6) {
                Text("Cardputer USB port").font(.system(size:12,weight:.medium))
                Picker("Cardputer USB port",selection:$m.selectedPort) {
                    if m.ports.isEmpty {Text("No Cardputer detected").tag("")}
                    ForEach(m.ports,id:\.self){Text($0).tag($0)}
                }.labelsHidden().disabled(busy)
            }
            Text(busy ? "Disconnect before changing devices or connection settings.":"Automatic selects Cardputer first, then Flipper. Each new connection starts disarmed.")
                .font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {Spacer();Button("Done"){settings=false}.keyboardShortcut(.defaultAction)}
        }.padding(18).frame(width:340)
    }
    private var pointer:some View {
        DashboardPanel {
            VStack(alignment:.leading,spacing:8) {
                HStack {SectionCaption(title:"Pointer position");Spacer();Text("macOS points").font(.system(size:10)).foregroundStyle(.secondary)}
                HStack(spacing:12) {
                    VStack(alignment:.leading,spacing:6) {
                        coordinate("X",m.x);coordinate("Y",m.y)
                    }.frame(minWidth:118,alignment:.leading)
                    Spacer(minLength:0)
                    ZStack(alignment:.topTrailing) {
                        MotionRadar(points:m.trail,aspect:CGFloat(m.screenWidth)/CGFloat(max(1,m.screenHeight)))
                        Image(systemName:m.moving ? "arrow.up":"circle.dotted").rotationEffect(.degrees(m.moving ? m.motionAngle:0))
                            .font(.system(size:11)).foregroundStyle(Palette.accent).padding(2)
                    }.frame(width:144,height:88).help("Last ten positions; proportions follow the display beneath the pointer")
                }
            }.frame(maxWidth:.infinity,minHeight:124,alignment:.topLeading)
        }
    }
    private func coordinate(_ axis:String,_ value:Int)->some View {
        HStack(alignment:.firstTextBaseline,spacing:10) {
            Text(axis).font(.system(size:11,weight:.medium)).foregroundStyle(Palette.accent).frame(width:10)
            Text(value.formatted(.number.grouping(.never))).font(.system(size:25,weight:.medium,design:.monospaced)).monospacedDigit()
        }.accessibilityElement(children:.combine)
    }
    private var inputState:some View {
        DashboardPanel {
            VStack(alignment:.leading,spacing:8) {
                HStack {
                    Text(m.armed ? "ARMED · \(m.remaining)s":"DISARMED").font(.system(size:16,weight:.semibold,design:.monospaced))
                        .foregroundStyle(m.armed ? Palette.scrollDown:Palette.healthy)
                    Spacer(minLength:4)
                    HStack(spacing:4) {ForEach(0..<3){i in
                        Text(["L","R","M"][i]).font(.system(size:10,weight:.semibold,design:.monospaced)).frame(width:23,height:20)
                            .background(m.mouseColor(i),in:RoundedRectangle(cornerRadius:4))
                            .foregroundStyle(((m.physicalButtons & (1 << i)) != 0 || (i==2 && m.wheelActive)) ? Color.black:Color.secondary)
                    }}.help("Observed left, right and middle buttons; middle pulses while scrolling")
                }
                HStack(spacing:10) {
                    Label(m.hid ? "HID ready":"HID waiting",systemImage:m.hid ? "checkmark.circle":"circle.dashed")
                    Spacer(minLength:0)
                    Text("\(m.roundTrip) ms").monospacedDigit()
                    Text("Held \(m.buttons)")
                }.font(.system(size:11)).foregroundStyle(.secondary)
                Spacer(minLength:0)
                HStack(spacing:8) {
                    Button("Arm 60s"){m.submit("arm")}.disabled(!m.connected || !m.hid || m.armed).help("Enable mouse commands for 60 seconds")
                    Spacer(minLength:0)
                    Button {m.stop()} label:{Label("STOP",systemImage:"stop.fill").font(.system(size:12,weight:.semibold)).frame(width:78)}
                        .buttonStyle(.plain).foregroundStyle(.white).padding(.vertical,6).padding(.horizontal,10)
                        .background(Color(red:0.72,green:0.20,blue:0.25),in:RoundedRectangle(cornerRadius:6)).keyboardShortcut(".",modifiers:.command)
                        .help(m.deviceName == "Flipper Zero" ? "Release input and disconnect Flipper":"Release input and disarm")
                }.controlSize(.regular)
            }.frame(maxWidth:.infinity,minHeight:124,alignment:.topLeading)
        }
    }
    private var application:some View {
        DashboardPanel {
            HStack(alignment:.center,spacing:16) {
                VStack(alignment:.leading,spacing:4) {
                    SectionCaption(title:"Active app")
                    Text(m.activeApp).font(.system(size:13,weight:.semibold)).lineLimit(1).help("Frontmost application")
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.leading,spacing:4) {
                    SectionCaption(title:"Under pointer")
                    Text(m.underPointer).font(.system(size:13)).lineLimit(1)
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.trailing,spacing:4) {
                    SectionCaption(title:"Mouse activity")
                    Text(m.lastInput).font(.system(size:12,weight:.medium)).foregroundStyle(Palette.accent).lineLimit(1).help(m.lastInput)
                }.frame(maxWidth:.infinity,alignment:.trailing)
            }
        }
    }
    private var console:some View {
        DashboardPanel {
            VStack(alignment:.leading,spacing:10) {
                HStack(spacing:12) {
                    Picker("Dashboard details",selection:$tab) {ForEach(["Activity","Apps","Display"],id:\.self){Text($0)}}
                        .pickerStyle(.segmented).labelsHidden().frame(width:222,alignment:.leading)
                    Spacer(minLength:0)
                    Toggle("Overlay",isOn:$m.overlayEnabled).help("Show the click-through pointer overlay")
                    Toggle("Device screen",isOn:$m.mirrorEnabled).help("Send observed pointer and app information to the device display")
                }.toggleStyle(.switch).controlSize(.mini).font(.system(size:11))
                HStack(spacing:8) {
                    TextField("Command · status, move 20 0, scroll -2",text:$m.command)
                        .textFieldStyle(.roundedBorder).font(.system(size:12,design:.monospaced)).onSubmit{m.submit()}
                        .accessibilityLabel("Mouse command")
                    Button("Send"){m.submit()}.disabled(!m.connected).frame(width:54)
                }.controlSize(.regular)
                Group {
                    if tab == "Activity" {activity}
                    else if tab == "Apps" {apps}
                    else {display}
                }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            }
        }
    }
    private var activity:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {SectionCaption(title:"Command activity");Spacer();Text("\(m.completed) replies").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)}
            ScrollViewReader {proxy in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:5) {
                        if m.logs.isEmpty {Text("Connect a device to see command replies. Viewing does not require arming.").font(.system(size:12)).foregroundStyle(.secondary).padding(.top,4)}
                        ForEach(m.logs){entry in
                            HStack(alignment:.top,spacing:10) {
                                Text(entry.time.formatted(date:.omitted,time:.standard)).foregroundStyle(.secondary).frame(width:82,alignment:.leading)
                                Text(entry.message).foregroundStyle(entry.message.contains("ERR") ? Palette.scrollDown:Color.primary).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                            }.font(.system(size:11,design:.monospaced)).id(entry.id)
                        }
                    }.frame(maxWidth:.infinity,alignment:.leading)
                }.onChange(of:m.logs.count){if let id=m.logs.last?.id {proxy.scrollTo(id,anchor:.bottom)}}
            }
        }
    }
    private var apps:some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:9) {
                SectionCaption(title:"Running applications · \(m.runningApps.count)")
                ForEach(m.runningApps,id:\.self){name in HStack(spacing:8) {
                    Circle().fill(name==m.activeApp ? Palette.accent:Color.secondary.opacity(0.4)).frame(width:5,height:5)
                    Text(name).font(.system(size:12)).textSelection(.enabled)
                    if name==m.activeApp {Text("Active").font(.system(size:10)).foregroundStyle(Palette.accent)}
                }}
            }.frame(maxWidth:.infinity,alignment:.leading)
        }
    }
    private var display:some View {
        Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:9) {
            GridRow {SectionCaption(title:"Display \(m.displayNumber)");Text(m.screenName)}
            GridRow {SectionCaption(title:"Resolution");Text("\(m.screenWidth) × \(m.screenHeight) points · \(m.scale,specifier:"%.0f")× scale")}
            GridRow {SectionCaption(title:"Local position");Text("X \(m.localX) · Y \(m.localY)").monospacedDigit()}
            GridRow {SectionCaption(title:"Radar");Text("Ten-position trail · origin upper-left · X →, Y ↓")}
            GridRow {SectionCaption(title:"Pointer target");Picker("Pointer target",selection:$m.overlayStyle){Text("Classic").tag("Classic");Text("Quiet RGB").tag("Quiet RGB")}.labelsHidden().frame(width:180,alignment:.leading).help("Classic keeps the original. Quiet RGB adds slow idle color and gentle action pulses.")}
        }.font(.system(size:12)).textSelection(.enabled)
    }
}
