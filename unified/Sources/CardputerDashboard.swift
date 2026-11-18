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

final class MarkerView:NSView {
    var point=NSPoint.zero
    var caption=""
    override var isOpaque:Bool {false}
    override func draw(_ dirtyRect:NSRect) {
        let p=point
        NSColor.black.withAlphaComponent(0.65).setStroke()
        let halo=NSBezierPath(ovalIn:NSRect(x:p.x-13,y:p.y-13,width:26,height:26));halo.lineWidth=5;halo.stroke()
        NSColor.systemCyan.setStroke()
        let ring=NSBezierPath(ovalIn:NSRect(x:p.x-12,y:p.y-12,width:24,height:24));ring.lineWidth=1.5;ring.stroke()
        let cross=NSBezierPath();cross.move(to:NSPoint(x:p.x-25,y:p.y));cross.line(to:NSPoint(x:p.x-7,y:p.y));cross.move(to:NSPoint(x:p.x+7,y:p.y));cross.line(to:NSPoint(x:p.x+25,y:p.y));cross.move(to:NSPoint(x:p.x,y:p.y-25));cross.line(to:NSPoint(x:p.x,y:p.y-7));cross.move(to:NSPoint(x:p.x,y:p.y+7));cross.line(to:NSPoint(x:p.x,y:p.y+25));cross.lineWidth=1.5;cross.stroke()
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.white]
        let str=caption as NSString;let size=str.size(withAttributes:attrs)
        let x=max(6,min(p.x+27,bounds.width-size.width-18))
        let y=max(6,min(p.y-37,bounds.height-size.height-12))
        NSColor.black.withAlphaComponent(0.8).setFill();NSBezierPath(roundedRect:NSRect(x:x-6,y:y-5,width:size.width+12,height:size.height+10),xRadius:5,yRadius:5).fill()
        str.draw(at:NSPoint(x:x,y:y),withAttributes:attrs)
    }
}
final class Overlay {
    var windows=[NSPanel]()
    func setEnabled(_ enabled:Bool) {
        windows.forEach{$0.orderOut(nil)};windows=[]
        guard enabled else{return}
        for screen in NSScreen.screens {
            let w=NSPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            w.isOpaque=false;w.backgroundColor = .clear;w.hasShadow=false;w.ignoresMouseEvents=true
            w.level = .floating;w.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
            w.hidesOnDeactivate=false;w.isReleasedWhenClosed=false;w.contentView=MarkerView(frame:NSRect(origin:.zero,size:screen.frame.size))
            w.orderFrontRegardless();windows.append(w)
        }
    }
    func update(_ p:NSPoint,_ caption:String) {
        for w in windows {
            if let v=w.contentView as? MarkerView {
                let hidden = !w.frame.contains(p)
                if v.isHidden != hidden {v.isHidden=hidden}
                guard !hidden else {continue}
                let point=NSPoint(x:p.x-w.frame.minX,y:p.y-w.frame.minY)
                if v.point != point || v.caption != caption {v.point=point;v.caption=caption;v.needsDisplay=true}
            }
        }
    }
}

final class Dashboard:ObservableObject {
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
        refreshPorts();overlay.setEnabled(true)
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
            wheelDirection=abs(dy)>=abs(dx) ? (dy>0 ? 1:-1):0
            let direction=abs(dy)>=abs(dx) ? (dy>0 ? "UP":"DOWN") : (dx>0 ? "LEFT":"RIGHT")
            lastInput="SCROLL \(direction)"
        case .leftMouseDown,.rightMouseDown,.otherMouseDown:
            let count=clicks.down(button:observedButton,point:NSEvent.mouseLocation,time:now,systemCount:event.clickCount,interval:NSEvent.doubleClickInterval)
            observedKind=count==2 ? 6:2
            lastInput=observedKind==6 ? "DOUBLE CLICK · \(name)":"PRESS · \(name)"
        case .leftMouseUp,.rightMouseUp,.otherMouseUp:
            observedKind=(event.clickCount==2 || clicks.count(button:observedButton)==2) ? 6:3
            lastInput=observedKind==6 ? "DOUBLE CLICK · \(name)":"CLICK · \(name)"
        default:
            observedKind=4;lastInput="DRAG · \(name)"
        }
        lastActionAt=now
        if connected {observationDirty=true}
    }
    func mouseColor(_ button:Int)->Color {
        if button==2 && wheelActive {return wheelDirection>0 ? Palette.healthy:(wheelDirection<0 ? Palette.scrollDown:Palette.accent)}
        return (physicalButtons & (1 << button)) != 0 ? Palette.accent:Color.white.opacity(0.06)
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
        if connected,pending==nil,queue.isEmpty {
            if viewportSupported && mirrorEnabled && viewportDirty {
                queue.append("viewport \(screenWidth) \(screenHeight)");viewportDirty=false
            }
            else if now-lastPoll>1 {lastPoll=now;queue.append("status")}
            else if mirrorSupported && mirrorEnabled && now-lastMirror>0.1 && (host != lastHost || now-lastMirror>0.75) {
                lastMirror=now;lastHost=host;queue.append(host)
            }
            else if observationDirty && observationSupported && mirrorEnabled && now-lastObservationSent>0.08 {
                let wx=Int(max(-100000,min(100000,(wheelX*10).rounded())))
                let wy=Int(max(-100000,min(100000,(wheelY*10).rounded())))
                let dx=max(-100000,min(100000,motionX)),dy=max(-100000,min(100000,motionY))
                queue.append("observe input \(observedKind) \(physicalButtons) \(observedButton) \(dx) \(dy) \(wx) \(wy)")
                wheelX=0;wheelY=0;observationDirty=false;lastObservationSent=now
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

enum Palette {
    static let background=Color(red:0.035,green:0.049,blue:0.075)
    static let panel=Color(red:0.068,green:0.090,blue:0.126)
    static let accent=Color(red:0.35,green:0.69,blue:1.0)
    static let healthy=Color(red:0.32,green:0.82,blue:0.66)
    static let scrollDown=Color(red:0.96,green:0.69,blue:0.29)
}
struct Tile<Content:View>:View {
    let title:String;let minimumHeight:CGFloat?;let content:Content
    init(_ title:String,minimumHeight:CGFloat?=nil,@ViewBuilder content:()->Content){self.title=title;self.minimumHeight=minimumHeight;self.content=content()}
    var body:some View {VStack(alignment:.leading,spacing:10){Text(title.uppercased()).font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(.secondary);content}.padding(16).frame(maxWidth:.infinity,minHeight:minimumHeight,alignment:.topLeading).background(Palette.panel,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Color.white.opacity(0.075)))}
}
struct DashboardView:View {
    @ObservedObject var m:Dashboard
    var body:some View {
        VStack(alignment:.leading,spacing:18){
            HStack(alignment:.top){
                VStack(alignment:.leading,spacing:6){
                    Label("HID EMU  /  DESKTOP CONTROL",systemImage:"computermouse").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(1.4).foregroundStyle(Palette.accent)
                    Text("HID Emu").font(.system(size:30,weight:.semibold))
                    Text("Flipper Zero + Cardputer · live pointer & command console").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment:.trailing,spacing:5){
                    Label(m.connected ? m.deviceName.uppercased()+" CONNECTED":"FLIPPER ZERO + CARDPUTER",systemImage:m.connected ? "circle.inset.filled":"circle").font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(m.connected ? Palette.healthy:Color.secondary)
                    Text(m.uptime).font(.system(size:27,weight:.medium,design:.monospaced)).monospacedDigit()
                    Text("CONTROL UPTIME · DEVICE SESSION").font(.system(size:9,weight:.medium,design:.monospaced)).foregroundStyle(.secondary)
                    Text("\(m.deviceName) · \(m.deviceVersion)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing:12){
                Tile("Pointer position & trail",minimumHeight:176) {
                    HStack(spacing:14){
                        VStack(alignment:.leading,spacing:8){
                            HStack(alignment:.firstTextBaseline){Text("X").font(.caption).foregroundStyle(Palette.accent);Text("\(m.x)").font(.system(size:28,weight:.medium,design:.monospaced)).monospacedDigit()}
                            HStack(alignment:.firstTextBaseline){Text("Y").font(.caption).foregroundStyle(Palette.accent);Text("\(m.y)").font(.system(size:28,weight:.medium,design:.monospaced)).monospacedDigit()}
                        };Spacer(minLength:4)
                        ZStack(alignment:.topTrailing){MotionRadar(points:m.trail,aspect:CGFloat(m.screenWidth)/CGFloat(max(1,m.screenHeight))).frame(width:130,height:96);Image(systemName:m.moving ? "arrow.up":"circle.dotted").font(.system(size:13,weight:.medium)).rotationEffect(.degrees(m.moving ? m.motionAngle:0)).foregroundStyle(Palette.accent)}
                    }
                    Text("macOS points · 10-position trail · display proportions").font(.caption2).foregroundStyle(.secondary)
                }
                Tile("Input state",minimumHeight:176) {HStack{Circle().fill(m.armed ? Color.orange:Palette.healthy).frame(width:9,height:9);Text(m.armed ? "ARMED · \(m.remaining)s":"DISARMED").font(.system(size:22,weight:.semibold,design:.monospaced))};Text("HID \(m.hid ? "ready":"waiting")  ·  bridge held \(m.buttons)  ·  RTT \(m.roundTrip) ms").font(.caption).foregroundStyle(.secondary);HStack(spacing:5){Text("MOUSE").font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary);ForEach(0..<3){i in Text(["L","R","M"][i]).font(.system(size:10,weight:.semibold,design:.monospaced)).frame(width:25,height:18).background(m.mouseColor(i),in:RoundedRectangle(cornerRadius:4)).foregroundStyle(((m.physicalButtons & (1 << i)) != 0 || (i==2 && m.wheelActive)) ? Color.black:Color.secondary)}}}
            }
            HStack(spacing:12){
                Tile("Active application") {Text(m.activeApp).font(.title3.bold());Text("Mouse target: \(m.underPointer)").font(.caption);Text(m.lastInput).font(.caption).foregroundStyle(Palette.accent)}
                Tile("Display \(m.displayNumber)") {Text(m.screenName).font(.title3.bold());Text("Local \(m.localX), \(m.localY)  ·  \(m.scale,specifier:"%.0f")× backing scale").font(.caption);Text("\(m.screenWidth) × \(m.screenHeight) points · radar matches display").font(.caption).foregroundStyle(.secondary)}
            }
            HStack(spacing:10){
                Picker("Device",selection:$m.deviceChoice){ForEach(["Automatic","Cardputer","Flipper Zero"],id:\.self){Text($0)}}.frame(width:230).disabled(m.connected || m.connecting)
                if m.deviceChoice != "Cardputer" {TextField("Flipper Bluetooth name",text:$m.flipperName).frame(width:170).disabled(m.connected || m.connecting)}
                Text("Automatic prefers Cardputer when both are available").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing:10){Picker("USB",selection:$m.selectedPort){if m.ports.isEmpty {Text("No Cardputer port").tag("")};ForEach(m.ports,id:\.self){Text($0).tag($0)}}.labelsHidden().frame(maxWidth:.infinity);Button(m.connected || m.connecting ? "Disconnect":"Connect"){if m.connected || m.connecting {m.disconnect()}else{m.connect()}};Button("Arm 60s"){m.submit("arm")}.disabled(!m.connected || !m.hid);Button("STOP"){m.stop()}.buttonStyle(.borderedProminent).tint(.red).keyboardShortcut(".",modifiers:.command)}
            HStack{Toggle("Pointer overlay",isOn:$m.overlayEnabled);Toggle("Mirror to device",isOn:$m.mirrorEnabled);Spacer();Text(m.connectionMessage).font(.caption).foregroundStyle(.secondary)}.toggleStyle(.switch).controlSize(.small)
            HStack(alignment:.top,spacing:12){
                Tile("Command console · \(m.completed) replies") {
                    HStack{TextField("status · move 20 0 · scroll -2 · drag left 40 0",text:$m.command).textFieldStyle(.roundedBorder).onSubmit{m.submit()};Button("Send"){m.submit()}.disabled(!m.connected)}
                    ScrollViewReader {proxy in ScrollView {LazyVStack(alignment:.leading,spacing:5){ForEach(m.logs){entry in HStack(alignment:.top,spacing:8){Text(entry.time,style:.time).foregroundStyle(.secondary);Text(entry.message).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.font(.system(size:11,design:.monospaced)).id(entry.id)}}.frame(maxWidth:.infinity,alignment:.leading)}.frame(minHeight:130,maxHeight:.infinity).onChange(of:m.logs.count){ if let id=m.logs.last?.id {proxy.scrollTo(id,anchor:.bottom)}}}
                }.frame(maxWidth:.infinity)
                Tile("Running apps · \(m.runningApps.count)") {ScrollView{VStack(alignment:.leading,spacing:7){ForEach(m.runningApps,id:\.self){name in HStack{Circle().fill(name==m.activeApp ? Palette.accent:Color.gray.opacity(0.5)).frame(width:5,height:5);Text(name).font(.caption)}}}.frame(maxWidth:.infinity,alignment:.leading)}.frame(minHeight:165,maxHeight:.infinity)}.frame(width:205)
            }.frame(maxHeight:.infinity)
            HStack{Text("\(m.deviceName=="Flipper Zero" ? "STOP / BACK ends Flipper session · reconnect to resume" : "STOP: ⌘. / S / G0 · held buttons release after 1.5s") · arm expires 60s").font(.caption2).foregroundStyle(.secondary);Spacer();Text("LOCAL DEVICE CONNECTION").font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundStyle(Palette.accent)}
        }.padding(22).frame(minWidth:920,minHeight:720).background(Palette.background).tint(Palette.accent).preferredColorScheme(.dark)
    }
}
final class AppDelegate:NSObject,NSApplicationDelegate {
    let model=Dashboard();var window:NSWindow!
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu=NSMenu();let item=NSMenuItem();menu.addItem(item);let sub=NSMenu();sub.addItem(withTitle:"Quit HID Emu",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=sub;NSApp.mainMenu=menu
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1020,height:800),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="HID Emu — Flipper Zero + Cardputer";window.titlebarAppearsTransparent=true;window.backgroundColor=NSColor(red:0.035,green:0.049,blue:0.075,alpha:1);window.contentView=NSHostingView(rootView:DashboardView(m:model));window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
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
