import AppKit
import SwiftUI
import Darwin

struct LogEntry: Identifiable { let id=UUID(); let time=Date(); let message:String }

final class SerialLink {
    var onLine: ((String)->Void)?
    var onFailure: ((String)->Void)?
    private var fd:Int32 = -1
    private var buffer=[UInt8]()
    var connected:Bool { fd >= 0 }
    func connect(_ path:String) throws {
        closeLink()
        fd=Darwin.open(path,O_RDWR|O_NOCTTY|O_NONBLOCK)
        guard fd >= 0 else { throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno)) }
        var t=termios()
        guard tcgetattr(fd,&t)==0 else { let e=errno;closeLink();throw NSError(domain:NSPOSIXErrorDomain,code:Int(e)) }
        cfmakeraw(&t);cfsetispeed(&t,speed_t(B115200));cfsetospeed(&t,speed_t(B115200))
        t.c_cflag |= tcflag_t(CLOCAL|CREAD)
        guard tcsetattr(fd,TCSANOW,&t)==0 else { let e=errno;closeLink();throw NSError(domain:NSPOSIXErrorDomain,code:Int(e)) }
        tcflush(fd,TCIFLUSH)
        // Prevent a second client from competing for command replies.
        _ = ioctl(fd,TIOCEXCL)
    }
    func closeLink() {
        if fd >= 0 { _ = ioctl(fd,TIOCNXCL);Darwin.close(fd) }
        fd = -1;buffer=[]
    }
    @discardableResult func write(_ line:String)->Bool {
        guard fd >= 0,let d=(line+"\n").data(using:.ascii),d.count<=97 else { return false }
        let count=d.withUnsafeBytes { Darwin.write(fd,$0.baseAddress,d.count) }
        if count != d.count { onFailure?("USB write failed; connection closed");closeLink();return false }
        return true
    }
    func poll() {
        guard fd >= 0 else { return }
        var bytes=[UInt8](repeating:0,count:1024)
        for _ in 0..<8 {
            let count=Darwin.read(fd,&bytes,bytes.count)
            if count>0 {
                for b in bytes.prefix(count) {
                    if b==10 {
                        let line=String(decoding:buffer,as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)
                        buffer=[];if !line.isEmpty { onLine?(line) }
                    } else if buffer.count<1024 {buffer.append(b)} else {buffer=[]}
                }
            } else {
                if count<0 && errno != EAGAIN && errno != EWOULDBLOCK { onFailure?("USB disconnected");closeLink() }
                break
            }
        }
    }
    deinit {closeLink()}
}

final class Dashboard:ObservableObject {
    var isFlipper:Bool {link.isFlipper}
    @Published var overlayStyle=UserDefaults.standard.string(forKey:"OverlayStyle") ?? "Classic" {didSet{overlay.style=overlayStyle;UserDefaults.standard.set(overlayStyle,forKey:"OverlayStyle")}}
    @Published var ports=[String]()
    @Published var selectedPort=""
    @Published var deviceChoice="Automatic"
    @Published var flipperName=UserDefaults.standard.string(forKey:"UnifiedFlipperName") ?? ""
    @Published var deviceName="No device"
    @Published var connecting=false
    @Published var connected=false
    @Published var hid=false
    @Published var armed=false
    @Published var buttons=0
    @Published var remaining=0
    @Published var x=0
    @Published var y=0
    @Published var localX=0
    @Published var localY=0
    @Published var screenName="—"
    @Published var screenWidth=1920
    @Published var screenHeight=1080
    @Published var displayNumber=1
    @Published var scale=1.0
    @Published var activeApp="—"
    @Published var underPointer="—"
    @Published var runningApps=[String]()
    @Published var logs=[LogEntry]()
    @Published var command=""
    @Published var overlayEnabled=true {didSet{overlay.setEnabled(overlayEnabled)}}
    @Published var mirrorEnabled=true
    @Published var deviceVersion="Checking…"
    @Published var mirrorSupported=false
    @Published var roundTrip=0
    @Published var completed=0
    @Published var uptime="00:00:00"
    @Published var lastInput="Waiting for mouse activity"
    @Published var physicalButtons=0
    @Published var moving=false
    @Published var wheelActive=false
    @Published var wheelDirection=0
    @Published var motionAngle=0.0
    @Published var trail=[CGPoint]()
    @Published var connectionMessage="Choose a device and connect"
    private let link=DeviceLink(),overlay=Overlay()
    private var timer:Timer?
    private var pending:String?
    private var sentAt=0.0
    private var queue=[String]()
    private var lastPoll=0.0,lastMirror=0.0,lastInventory=0.0,lastPortScan=0.0
    private var inputMonitors=[Any]()
    private var wheelX=0.0,wheelY=0.0,lastObservationSent=0.0
    private var observedSequence=0
    private var observedKind=0,observedButton=0,motionX=0,motionY=0
    private var lastActionAt=0.0,lastMotionAt=0.0,lastWheelAt=0.0
    private var previousPointer:NSPoint?
    private var observationDirty=false
    private var observationSupported=false
    private var viewportSupported=false,viewportDirty=true
    private var clicks=ClickTracker()
    private var lastHost=""
    private var connectedAt:Double?
    private var armDeadline=0.0
    private var lastReply=0.0
    private var now:Double {ProcessInfo.processInfo.systemUptime}
    init() {
        link.onLine={[weak self] in self?.received($0)}
        link.onFailure={[weak self] s in self?.failed(s)}
        link.onReady={[weak self] in self?.linkReady()}
        refreshPorts();overlay.style=overlayStyle;overlay.setEnabled(true)
        let events:NSEvent.EventTypeMask=[.scrollWheel,.leftMouseDown,.leftMouseUp,.rightMouseDown,.rightMouseUp,.otherMouseDown,.otherMouseUp,.leftMouseDragged,.rightMouseDragged,.otherMouseDragged]
        if let token=NSEvent.addGlobalMonitorForEvents(matching:events,handler:{[weak self] event in self?.observeInput(event)}) {inputMonitors.append(token)}
        if let token=NSEvent.addLocalMonitorForEvents(matching:events,handler:{[weak self] event in self?.observeInput(event);return event}) {inputMonitors.append(token)}
        timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true){[weak self] _ in self?.tick()}
        tick()
    }
    private func observeInput(_ event:NSEvent) {
        physicalButtons=Int(NSEvent.pressedMouseButtons & 31)
        observedButton=MouseButtons.index(type:event.type,reported:event.buttonNumber,control:event.modifierFlags.contains(.control))
        let name=["LEFT","RIGHT","MIDDLE","BACK","FORWARD"][observedButton]
        switch event.type {
        case .scrollWheel:
            let dx=Double(event.scrollingDeltaX),dy=Double(event.scrollingDeltaY)
            guard dx != 0 || dy != 0 else{return}
            wheelX+=dx;wheelY+=dy;observedKind=5;lastWheelAt=now;wheelActive=true
            wheelDirection=abs(dy)>=abs(dx) ? (dy>0 ? 1:-1):(dx>0 ? 2:-2)
            let direction=abs(dy)>=abs(dx) ? (dy>0 ? "UP":"DOWN") : (dx>0 ? "LEFT":"RIGHT")
            lastInput="SCROLL \(direction)"
            overlay.action(abs(dy)>=abs(dx) ? (dy>0 ? .scrollUp:.scrollDown):(dx>0 ? .scrollLeft:.scrollRight))
        case .leftMouseDown,.rightMouseDown,.otherMouseDown:
            let count=clicks.down(button:observedButton,point:NSEvent.mouseLocation,time:now,systemCount:event.clickCount,interval:NSEvent.doubleClickInterval)
            observedKind=count==2 ? 6:2
            overlay.action(observedButton==0 ? .left:(observedButton==1 ? .right:.middle),double:count==2)
            lastInput=observedKind==6 ? "DOUBLE CLICK · \(name)":"PRESS · \(name)"
        case .leftMouseUp,.rightMouseUp,.otherMouseUp:
            observedKind=(event.clickCount==2 || clicks.count(button:observedButton)==2) ? 6:3
            lastInput=observedKind==6 ? "DOUBLE CLICK · \(name)":"CLICK · \(name)"
        default:
            observedKind=4;lastInput="DRAG · \(name)"
        }
        observedSequence=(observedSequence+1)%100000
        lastActionAt=now
        if connected {observationDirty=true}
    }
    func mouseColor(_ button:Int)->Color {
        if button==2 && wheelActive {return wheelDirection==1 ? Palette.scrollUp:(wheelDirection == -1 ? Palette.scrollDown:(wheelDirection==2 ? Palette.left:Palette.right))}
        return (physicalButtons & (1 << button)) != 0 ? (button==0 ? Palette.left:(button==1 ? Palette.right:Palette.accent)):Color.white.opacity(0.06)
    }
    func log(_ message:String) {logs.append(LogEntry(message:message));if logs.count>180 {logs.removeFirst(logs.count-180)}}
    func refreshPorts() {
        ports=DeviceInventory.cardputerPorts()
        if !ports.contains(selectedPort) {selectedPort=ports.first ?? ""}
    }
    func connect() {
        guard !connected && !connecting else {return}
        refreshPorts()
        let useCardputer=deviceChoice=="Cardputer" || (deviceChoice=="Automatic" && !ports.isEmpty)
        deviceName=useCardputer ? "Cardputer ADV":"Flipper Zero"
        deviceVersion="Checking…"
        connecting=true;connectionMessage="Connecting to \(deviceName)…"
        UserDefaults.standard.set(flipperName,forKey:"UnifiedFlipperName")
        do {try link.connect(useCardputer ? selectedPort:"flipper://"+flipperName)}
        catch {failed("Cannot connect: \(error.localizedDescription)")}
    }
    private func linkReady() {
        connecting=false;connected=true;connectedAt=now;uptime="00:00:00";hid=false;armed=false;buttons=0
        connectionMessage="Checking \(deviceName)…";deviceVersion="Checking…";mirrorSupported=false;viewportSupported=false;viewportDirty=true;observationSupported=false;observationDirty=true;observedKind=0;wheelX=0;wheelY=0;lastHost=""
        lastReply=now;log("CONNECTED  \(deviceName)");queue=["ping","stop","status","info"];pump()
    }
    func disconnect() {
        if connected {_=link.write("stop")}
        link.closeLink();connecting=false;connected=false;connectedAt=nil;uptime="00:00:00";hid=false;armed=false;remaining=0;pending=nil;queue=[]
        connectionMessage="Disconnected";log("DISCONNECTED — STOP requested")
    }
    private func failed(_ message:String) {
        link.closeLink()
        connecting=false;connected=false;connectedAt=nil;uptime="00:00:00";hid=false;armed=false;remaining=0;pending=nil;queue=[]
        connectionMessage=message;log("ERROR  "+message)
    }
    func stop() {
        if link.isFlipper {disconnect();return}
        queue=[];pending=nil;armed=false;remaining=0
        guard connected else{return}
        pending="stop";sentAt=now;log("→ stop")
        if !link.write("stop") {failed("Unable to send STOP")}
    }
    func submit(_ input:String?=nil) {
        let text=(input ?? command).trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else{return}
        guard text.utf8.count<=96,text.unicodeScalars.allSatisfy({$0.value>=32 && $0.value<127}) else {log("REJECTED  Single ASCII command, maximum 96 characters");return}
        let verb=text.split(separator:" ").first.map(String.init) ?? ""
        let allowed=["ping","status","arm","move","click","double","down","up","drag","scroll","stop","quit","info"]
        guard allowed.contains(verb) else {log("REJECTED  Unknown command");return}
        if verb=="stop" {stop();return}
        guard connected else {log("REJECTED  Connect USB first");return}
        if !["ping","status","arm","quit","info"].contains(verb) && !armed {log("REJECTED  Arm the device before pointer input");return}
        guard queue.count<12 else {log("REJECTED  Command queue full");return}
        queue.append(text);if input==nil {command=""};pump()
    }
    private func pump() {
        guard connected,pending==nil,!queue.isEmpty else {return}
        let item=queue.removeFirst();pending=item;sentAt=now
        if !item.hasPrefix("host ") && !item.hasPrefix("observe ") && !item.hasPrefix("viewport ") && item != "status" {log("→ "+item)}
        if !link.write(item) {failed("USB write failed")}
    }
    private func received(_ line:String) {
        guard line.hasPrefix("OK ") || line.hasPrefix("ERR ") else {log(line);return}
        lastReply=now
        if line=="OK ARMED" {armed=true;armDeadline=now+60}
        if line=="OK STOP" || line=="OK QUIT" {armed=false;remaining=0;buttons=0}
        if line.hasPrefix("OK HID=") {
            for field in line.split(separator:" ") {
                let pair=field.split(separator:"=");guard pair.count==2 else{continue}
                if pair[0]=="HID" {hid=pair[1]=="1"}
                if pair[0]=="ARMED" {armed=pair[1]=="1"}
                if pair[0]=="BUTTONS" {buttons=Int(pair[1]) ?? 0}
            }
            connectionMessage=hid ? "\(deviceName) linked · device responding" : "Device linked · HID not ready"
        }
        if line.hasPrefix("OK BRIDGE=") {deviceVersion=String(line.dropFirst(10));mirrorSupported=true;observationSupported=(link.isFlipper || deviceVersion.compare("1.2.1",options:.numeric) != .orderedAscending);viewportSupported=(link.isFlipper || deviceVersion.compare("1.2.2",options:.numeric) != .orderedAscending)}
        if line.hasPrefix("ERR disarmed") {armed=false;remaining=0}
        guard let item=pending else {if line != "OK HOST" {log("← "+line)};return}
        let verb=item.split(separator:" ").first.map(String.init) ?? ""
        let expected:Bool
        if line.hasPrefix("ERR ") {expected=true}
        else {
            switch verb {
            case "ping":expected=line=="OK PONG"
            case "status":expected=line.hasPrefix("OK HID=")
            case "arm":expected=line=="OK ARMED"
            case "info":expected=line.hasPrefix("OK BRIDGE=")
            default:expected=line=="OK "+verb.uppercased()
            }
        }
        guard expected else{return}
        if !["host","observe","viewport"].contains(verb) {roundTrip=Int((now-sentAt)*1000)}
        if verb=="info" && line.hasPrefix("ERR") {deviceVersion="1.0 · screen upgrade needed";mirrorSupported=false}
        if verb != "host" && verb != "observe" && verb != "viewport" && verb != "status" {completed+=1;log("← "+line+"  [\(roundTrip) ms]")}
        pending=nil;pump()
    }
    private func ascii(_ text:String)->String {
        let plain=text.applyingTransform(.toLatin,reverse:false)?.applyingTransform(.stripDiacritics,reverse:false) ?? text
        return String(String.UnicodeScalarView(plain.unicodeScalars.filter{$0.value>=32 && $0.value<127})).prefix(44).description
    }
    private func tick() {
        let wheel=now-lastWheelAt<0.3
        if wheelActive != wheel {wheelActive=wheel}
        if let start=connectedAt {
            let elapsed=max(0,Int(now-start))
            let value=String(format:"%02d:%02d:%02d",elapsed/3600,(elapsed/60)%60,elapsed%60)
            if uptime != value {uptime=value}
        }
        let p=NSEvent.mouseLocation
        let sampledButtons=Int(NSEvent.pressedMouseButtons & 31)
        if sampledButtons != physicalButtons {physicalButtons=sampledButtons;if connected {observationDirty=true}}
        if let previous=previousPointer {
            let dx=Int((p.x-previous.x).rounded()),dy=Int((previous.y-p.y).rounded())
            if dx != 0 || dy != 0 {
                motionX=dx;motionY=dy;lastMotionAt=now;moving=true
                motionAngle=atan2(Double(dx),Double(-dy))*180/Double.pi
                if now-lastActionAt>0.75 {
                    observedKind=sampledButtons==0 ? 1:4
                    if sampledButtons != 0 {observedButton=(0..<5).first(where:{sampledButtons & (1 << $0) != 0}) ?? 0}
                    lastInput=sampledButtons==0 ? "MOVING":"DRAG · \(["LEFT","RIGHT","MIDDLE","BACK","FORWARD"][observedButton])"
                }
                if connected {observationDirty=true}
            } else if now-lastMotionAt>0.3 && moving {
                moving=false;motionX=0;motionY=0;if connected {observationDirty=true}
            }
        }
        previousPointer=p
        let primaryTop=NSScreen.screens.first?.frame.maxY ?? 0
        let newX=Int(p.x.rounded()),newY=Int((primaryTop-p.y).rounded())
        if x != newX {x=newX};if y != newY {y=newY}
        let sample=CGPoint(x:x,y:y)
        if trail.last != sample {trail.append(sample);if trail.count>10 {trail.removeFirst(trail.count-10)}}
        if let i=NSScreen.screens.firstIndex(where:{$0.frame.contains(p)}) {
            let s=NSScreen.screens[i]
            if displayNumber != i+1 {displayNumber=i+1;viewportDirty=true}
            if screenName != s.localizedName {screenName=s.localizedName}
            if scale != s.backingScaleFactor {scale=s.backingScaleFactor}
            let width=Int(s.frame.width),height=Int(s.frame.height)
            if width != screenWidth || height != screenHeight {screenWidth=width;screenHeight=height;viewportDirty=true}
            let lx=Int(p.x-s.frame.minX),ly=Int(s.frame.maxY-p.y)
            if localX != lx {localX=lx};if localY != ly {localY=ly}
        }
        let front=NSWorkspace.shared.frontmostApplication
        let appName=front?.localizedName ?? "—"
        if activeApp != appName {activeApp=appName}
        overlay.heldButtons=sampledButtons
        overlay.update(p,"\(x), \(y)  ·  \(activeApp)")
        if now-lastInventory>1 {
            lastInventory=now
            let apps=Array(Set(NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular}.compactMap{$0.localizedName})).sorted()
            if runningApps != apps {runningApps=apps}
            let point=CGPoint(x:p.x,y:primaryTop-p.y)
            if let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] {
                var ownerName="—"
                for w in windows where (w[kCGWindowLayer as String] as? Int)==0 {
                    guard let bounds=w[kCGWindowBounds as String] as? [String:Any],let rect=CGRect(dictionaryRepresentation:bounds as CFDictionary),rect.contains(point),let owner=w[kCGWindowOwnerName as String] as? String else{continue}
                    ownerName=owner;break
                }
                if underPointer != ownerName {underPointer=ownerName}
            }
        }
        if now-lastPortScan>3 {lastPortScan=now;if !connected && !connecting {refreshPorts()}}
        if armed {remaining=max(0,Int(ceil(armDeadline-now)));if remaining==0 {armed=false}}
        link.poll()
        if connected,let item=pending,now-sentAt>3 {
            _=link.write("stop");failed("USB timeout: "+item+" — reconnect required");return
        }
        if connected,now-lastReply>4 {
            _=link.write("stop");failed("USB replies stale — reconnect required");return
        }
        let host="host \(x) \(y) \(displayNumber) \(ascii(activeApp))"
        let hostDue=mirrorSupported && mirrorEnabled && now-lastMirror>0.1 && (host != lastHost || now-lastMirror>0.75)
        let observationDue=observationDirty && observationSupported && mirrorEnabled && now-lastObservationSent>0.08
        let telemetry=TelemetrySchedule.next(hostDue:hostDue,observationDue:observationDue,lastHost:lastMirror,lastObservation:lastObservationSent)
        if connected,pending==nil,queue.isEmpty {
            if viewportSupported && mirrorEnabled && viewportDirty {
                queue.append("viewport \(screenWidth) \(screenHeight)");viewportDirty=false
            }
            else if now-lastPoll>1 {lastPoll=now;queue.append("status")}
            else if telemetry == .observation {
                let wx=Int(max(-100000,min(100000,(wheelX*10).rounded())))
                let wy=Int(max(-100000,min(100000,(wheelY*10).rounded())))
                let dx=max(-100000,min(100000,motionX)),dy=max(-100000,min(100000,motionY))
                let eventProtocol=deviceVersion.compare(link.isFlipper ? "1.2.0":"1.4.0",options:.numeric) != .orderedAscending
                let prefix=eventProtocol ? "observe event \(observedSequence)":"observe input"
                queue.append("\(prefix) \(observedKind) \(physicalButtons) \(observedButton) \(dx) \(dy) \(wx) \(wy)")
                wheelX=0;wheelY=0;observationDirty=false;lastObservationSent=now
            }
            else if telemetry == .host {
                lastMirror=now;lastHost=host;queue.append(host)
            }
            pump()
        }
    }
    func shutdown(){timer?.invalidate();stop();link.closeLink();overlay.setEnabled(false);inputMonitors.forEach{NSEvent.removeMonitor($0)};inputMonitors=[]}
}

struct MotionRadar:View {
    let points:[CGPoint]
    let aspect:CGFloat
    var body:some View {
        Canvas {context,size in
            let center=CGPoint(x:size.width/2,y:size.height/2)
            let available=CGSize(width:size.width-10,height:size.height-12)
            let width=min(available.width,available.height*aspect),height=min(available.height,available.width/aspect)
            let rect=CGRect(x:center.x-width/2,y:center.y-height/2,width:width,height:height)
            let grid=Color.white.opacity(0.13)
            context.stroke(Path(rect),with:.color(Palette.accent.opacity(0.4)),lineWidth:1)
            let inner=CGRect(x:center.x-width/4,y:center.y-height/4,width:width/2,height:height/2)
            context.stroke(Path(inner),with:.color(grid),lineWidth:1)
            var axes=Path();axes.move(to:CGPoint(x:rect.minX,y:center.y));axes.addLine(to:CGPoint(x:rect.maxX,y:center.y));axes.move(to:CGPoint(x:center.x,y:rect.minY));axes.addLine(to:CGPoint(x:center.x,y:rect.maxY));context.stroke(axes,with:.color(grid),lineWidth:1)
            guard let newest=points.last else{return}
            let scale=points.reduce(CGFloat(1)){max($0,max(abs($1.x-newest.x)/max(1,width/2-4),abs($1.y-newest.y)/max(1,height/2-4)))}*1.15
            let mapped=points.map{CGPoint(x:center.x+($0.x-newest.x)/scale,y:center.y+($0.y-newest.y)/scale)}
            if let first=mapped.first {
                var line=Path();line.move(to:first);mapped.dropFirst().forEach{line.addLine(to:$0)}
                context.stroke(line,with:.color(Palette.accent.opacity(0.55)),lineWidth:1.3)
            }
            for (i,p) in mapped.enumerated() {
                let newest=i==mapped.count-1,r:CGFloat=newest ? 3.5:2
                context.fill(Path(ellipseIn:CGRect(x:p.x-r,y:p.y-r,width:2*r,height:2*r)),with:.color(Palette.accent.opacity(newest ? 1:0.22+Double(i)/12)))
            }
        }.accessibilityLabel("Last ten pointer positions, centered on the newest position")
    }
}

final class AppDelegate:NSObject,NSApplicationDelegate {
    let model=Dashboard();var window:NSWindow!
    func applicationDidFinishLaunching(_ notification:Notification) {
        // Supply the running Dock tile explicitly, including direct executable launches.
        if let url=Bundle.main.url(forResource:"HIDEmu",withExtension:"icns"),let icon=NSImage(contentsOf:url) {
            NSApp.applicationIconImage=icon
        }
        NSApp.setActivationPolicy(.regular)
        let menu=NSMenu();let item=NSMenuItem();menu.addItem(item);let sub=NSMenu();sub.addItem(withTitle:"Quit HID Emu",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=sub
        let viewItem=NSMenuItem();menu.addItem(viewItem);let viewMenu=NSMenu(title:"View")
        let compact=NSMenuItem(title:"Compact Window",action:#selector(compactWindow),keyEquivalent:"1");compact.target=self;viewMenu.addItem(compact)
        let normal=NSMenuItem(title:"Default Window Size",action:#selector(defaultWindow),keyEquivalent:"0");normal.target=self;viewMenu.addItem(normal)
        viewItem.submenu=viewMenu;NSApp.mainMenu=menu
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title=AppIdentity.windowTitle;window.contentMinSize=NSSize(width:720,height:580);window.titlebarAppearsTransparent=true;window.backgroundColor=NSColor(red:0.035,green:0.049,blue:0.075,alpha:1);window.contentView=NSHostingView(rootView:DashboardView(m:model));window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func compactWindow(){window.setContentSize(NSSize(width:720,height:580))}
    @objc func defaultWindow(){window.setContentSize(NSSize(width:760,height:620))}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if FirmwareCenter.shared.installing {NSSound.beep();return .terminateCancel}
        return .terminateNow
    }
    func applicationWillTerminate(_ n:Notification){model.shutdown()}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
}
@main struct DashboardApp {
    static func main() {
        if CommandLine.arguments.count==3 && CommandLine.arguments[1]=="--register-cardputer" {
            var list=UserDefaults.standard.stringArray(forKey:"CardputerSerials") ?? []
            let serial=CommandLine.arguments[2];if !list.contains(serial) {list.append(serial)}
            UserDefaults.standard.set(list,forKey:"CardputerSerials");print("Cardputer enrolled");return
        }
        if CommandLine.arguments.contains("--list-devices") {print(DeviceInventory.cardputerPorts().joined(separator:"\n"));return}
        if CommandLine.arguments.count==3 && CommandLine.arguments[1]=="--capture-flipper" {
            FlipperScreenCapture.run(path:CommandLine.arguments[2]);return
        }
        let app=NSApplication.shared
        let delegate=AppDelegate();app.delegate=delegate;app.run()
    }
}
