import AppKit
import UniformTypeIdentifiers
import Darwin

final class ControlPanel:NSObject,NSApplicationDelegate {
    let preview:Bool
    let bridge=MouseBridge()
    lazy var target=TargetController(bridge:bridge)
    var window:NSWindow!
    let name=NSTextField(string:UserDefaults.standard.string(forKey:"DeviceName") ?? "Flipper")
    let status=NSTextField(labelWithString:"OFFLINE")
    let detail=NSTextField(wrappingLabelWithString:"Select a target app, connect your Flipper, then enable mouse control.")
    let pointerLabel=NSTextField(labelWithString:"X —    Y —")
    let relativeLabel=NSTextField(labelWithString:"Select a target to see window coordinates")
    let focusLabel=NSTextField(labelWithString:"NO TARGET")
    let commandLabel=NSTextField(labelWithString:"Idle")
    let metricsLabel=NSTextField(wrappingLabelWithString:"Queue 0 · no commands yet")
    let map=PointerMap()
    let entry=NSTextField(string:"CLICK 1 1")
    let coordinates=NSTextField(string:"50 50")
    let apps=NSPopUpButton()
    let presets=NSPopUpButton()
    let connectButton=NSButton(title:"Connect",target:nil,action:nil)
    let armButton=NSButton(title:"Enable mouse",target:nil,action:nil)
    let prepareButton=NSButton(title:"Prepare target",target:nil,action:nil)
    let sendButton=NSButton(title:"Position + send",target:nil,action:nil)
    let hereButton=NSButton(title:"Use target pointer",target:nil,action:nil)
    let stopButton=NSButton(title:"STOP & RELEASE",target:nil,action:nil)
    let chooseButton=NSButton(title:"Choose app…",target:nil,action:nil)
    let reloadButton=NSButton(title:"Refresh",target:nil,action:nil)
    let logView=NSTextView()
    var lines=[String]()
    var ticker:Timer?
    var observedBounds:CGRect?
    var lastWindowPoll=0.0
    var lastTargetPointerBounds:CGRect?
    var lastTargetPointer:CGPoint?
    var lastTargetPointerTime=0.0
    let renderOnly:Bool
    init(preview:Bool=false,renderOnly:Bool=false) { self.preview=preview;self.renderOnly=renderOnly;super.init() }
    func applicationDidFinishLaunching(_ notification:Notification) {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:760),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.4.0"
        window.title="ChatGPT Mouse Controller · \(version)";window.appearance=NSAppearance(named:.darkAqua);window.center()
        let view=window.contentView!;view.wantsLayer=true;view.layer?.backgroundColor=NSColor(calibratedRed:0.045,green:0.06,blue:0.10,alpha:1).cgColor
        func label(_ text:String,_ x:Double,_ y:Double,_ w:Double,_ size:Double=12)->NSTextField {
            let f=NSTextField(labelWithString:text);f.frame=NSRect(x:x,y:y,width:w,height:24);f.font = .systemFont(ofSize:size,weight:.medium);f.textColor = .secondaryLabelColor;view.addSubview(f);return f
        }
        func card(_ x:Double,_ y:Double,_ w:Double,_ h:Double) {
            let v=NSView(frame:NSRect(x:x,y:y,width:w,height:h));v.wantsLayer=true;v.layer?.cornerRadius=16;v.layer?.backgroundColor=NSColor(calibratedRed:0.09,green:0.11,blue:0.16,alpha:1).cgColor;view.addSubview(v)
        }
        func field(_ f:NSTextField,_ x:Double,_ y:Double,_ w:Double,_ h:Double=26) { f.frame=NSRect(x:x,y:y,width:w,height:h);view.addSubview(f) }
        func button(_ b:NSButton,_ x:Double,_ y:Double,_ w:Double,_ action:Selector) { b.frame=NSRect(x:x,y:y,width:w,height:32);b.bezelStyle = .rounded;b.target=self;b.action=action;view.addSubview(b) }
        let title=label("ChatGPT Mouse Controller",24,704,650,26);title.textColor = .labelColor;title.frame.size.height=36
        _=label("LOCAL CONTROL  /  BLUETOOTH COMMANDS → USB MOUSE",26,675,680,11)
        status.frame=NSRect(x:720,y:711,width:190,height:24);status.alignment = .right;status.textColor = .systemTeal;status.font = .systemFont(ofSize:12,weight:.bold);view.addSubview(status)
        card(24,426,540,238);card(580,426,336,238)
        _=label("LIVE POINTER  /  LAST 20 POSITIONS",42,625,500,11)
        pointerLabel.font = .monospacedSystemFont(ofSize:25,weight:.medium);field(pointerLabel,42,586,500,36)
        field(relativeLabel,42,558,500,24)
        map.frame=NSRect(x:40,y:443,width:508,height:110);map.wantsLayer=true;map.layer?.cornerRadius=10;view.addSubview(map)
        _=label("COMMAND MONITOR",598,625,300,11)
        commandLabel.font = .monospacedSystemFont(ofSize:16,weight:.medium);field(commandLabel,598,582,300,36)
        field(metricsLabel,598,550,300,28);metricsLabel.font = .monospacedSystemFont(ofSize:11,weight:.regular)
        field(focusLabel,598,520,300,24);focusLabel.textColor = .systemTeal
        detail.font = .systemFont(ofSize:12);field(detail,598,447,300,65)
        card(24,250,892,162)
        _=label("CONNECTION & TARGET",42,377,400,11)
        field(name,42,345,190)
        button(connectButton,240,342,100,#selector(connect));button(armButton,350,342,135,#selector(arm));button(stopButton,701,342,195,#selector(stop));stopButton.contentTintColor = .systemOrange
        apps.frame=NSRect(x:42,y:300,width:340,height:30);apps.target=self;apps.action=#selector(selectApp);view.addSubview(apps)
        button(reloadButton,390,299,90,#selector(reloadApps));button(chooseButton,488,299,120,#selector(chooseApp));button(prepareButton,620,299,150,#selector(prepare))
        _=label("Explicit target selection · one controller · fresh enable after reconnect",42,265,800,11)
        card(24,124,892,112)
        _=label("ACTION",42,201,90,11)
        presets.frame=NSRect(x:110,y:200,width:160,height:28);presets.addItems(withTitles:["Left click","Double click","Right click","Scroll down","Scroll up","Drag down","Position only"]);presets.target=self;presets.action=#selector(preset);view.addSubview(presets)
        _=label("X / Y % of target window",295,202,270,11)
        field(coordinates,575,201,125)
        field(entry,42,154,355)
        button(hereButton,411,151,170,#selector(sendHere));button(sendButton,596,151,180,#selector(send))
        _=label("Pointer coordinates use screen points from top left. Stop disconnects and releases input.",42,101,855,11)
        let scroll=NSScrollView(frame:NSRect(x:24,y:20,width:892,height:78));scroll.hasVerticalScroller=true;scroll.borderType = .noBorder
        logView.isEditable=false;logView.font = .monospacedSystemFont(ofSize:11,weight:.regular);logView.backgroundColor=NSColor(calibratedWhite:0.06,alpha:1);scroll.documentView=logView;view.addSubview(scroll)
        bridge.onLog={ [weak self] text in self?.append(text) }
        bridge.onState={ [weak self] state,reason in
            guard let self else {return};if state != .armed {self.target.cancel()}
            self.status.stringValue=[BridgeState.disconnected:"OFFLINE",.initializing:"BLUETOOTH SETUP",.scanning:"DISCOVERING",.connecting:"CONNECTING",.starting:"STARTING",.ready:"CONNECTED · SAFE",.armed:"CONNECTED · ARMED",.stopping:"RELEASING",.failed:"CONNECTION FAILED"][state]!;if !reason.isEmpty {self.detail.stringValue=reason};self.refresh()
        }
        target.onStatus={ [weak self] text in self?.detail.stringValue=text }
        let menu=NSMenu();let item=NSMenuItem();menu.addItem(item)
        let appMenu=NSMenu();appMenu.addItem(withTitle:"Quit ChatGPT Mouse Controller",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=appMenu;NSApp.mainMenu=menu
        reloadApps();refresh();tick()
        ticker=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.tick() }
        if renderOnly {name.stringValue="Flipper"}
        if preview {detail.stringValue="Read-only dashboard preview. Mouse input and connection are disabled.";status.stringValue="PREVIEW"}
        if !renderOnly {window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    }
    func append(_ text:String) {
        let stamp=DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.medium)
        lines.append("\(stamp)  \(text)");if lines.count>200 {lines.removeFirst(lines.count-200)}
        logView.string=lines.joined(separator:"\n")+"\n";logView.scrollToEndOfDocument(nil)
    }
    func tick() {
        guard renderOnly || window?.isVisible == true else {return}
        let now=ProcessInfo.processInfo.systemUptime
        if now-lastWindowPoll>0.5 {observedBounds=target.windowBounds();lastWindowPoll=now}
        let p=CGEvent(source:nil)?.location
        if let p {
            if target.hasFocus,let b=observedBounds,b.insetBy(dx:4,dy:4).contains(p) {lastTargetPointer=p;lastTargetPointerBounds=b;lastTargetPointerTime=now}
            pointerLabel.stringValue=String(format:"X %.1f    Y %.1f",p.x,p.y)
            if let b=observedBounds {relativeLabel.stringValue=String(format:"Window %.1f / %.1f pt  ·  %.1f%% / %.1f%%",p.x-b.minX,p.y-b.minY,(p.x-b.minX)/b.width*100,(p.y-b.minY)/b.height*100)}
            else {relativeLabel.stringValue="Screen points · target window unavailable"}
        }
        map.update(p,bounds:observedBounds)
        if !preview {bridge.updatePointer(p,busy:target.busy)}
        focusLabel.stringValue="\(target.hasFocus ? "FOCUSED" : "NOT FOCUSED") · \(target.targetName)"
        commandLabel.stringValue=bridge.activeCommand.map { $0+String(format:" · %.0f ms",(bridge.activeElapsed ?? 0)*1000) } ?? (target.busy ? "Positioning / focusing…" : (bridge.lastCommand.map { "Last: "+$0 } ?? "Idle"))
        let latency=bridge.lastLatency.map{String(format:"%.0f ms",$0*1000)} ?? "—"
        let average=bridge.averageLatency.map{String(format:"%.0f ms",$0*1000)} ?? "—"
        metricsLabel.stringValue="Queue \(bridge.queuedCount) · completed \(bridge.completedCommands)\nLast \(latency) · moving avg \(average)"
        refresh()
    }
    func refresh() {
        connectButton.isEnabled = !preview && bridge.canConnect;name.isEnabled=bridge.canConnect
        armButton.isEnabled = !preview && bridge.state == .ready
        prepareButton.isEnabled = !preview && bridge.isArmed && !target.busy
        sendButton.isEnabled = !preview && bridge.isArmed && !target.busy && target.focusedApp != nil
        hereButton.isEnabled=sendButton.isEnabled
        stopButton.isEnabled = !preview && !bridge.canConnect
        apps.isEnabled = !target.busy;chooseButton.isEnabled = !target.busy;reloadButton.isEnabled = !target.busy
    }
    @objc func reloadApps() {
        let pid=target.selectedPID
        apps.removeAllItems();apps.addItem(withTitle:"Select a running application…")
        for app in NSWorkspace.shared.runningApplications.filter({$0.activationPolicy == .regular && $0.processIdentifier != getpid() && $0.bundleIdentifier != Bundle.main.bundleIdentifier}).sorted(by:{($0.localizedName ?? "")<($1.localizedName ?? "")}) {
            apps.addItem(withTitle:"\(app.localizedName ?? "App") · PID \(app.processIdentifier)");apps.lastItem?.representedObject=NSNumber(value:app.processIdentifier)
            if app.processIdentifier==pid {apps.select(apps.lastItem)}
        }
    }
    @objc func selectApp() {
        guard !target.busy,let pid=(apps.selectedItem?.representedObject as? NSNumber)?.int32Value,let app=NSRunningApplication(processIdentifier:pid) else {return}
        target.select(app);observedBounds=nil;lastTargetPointer=nil;refresh()
    }
    @objc func chooseApp() {
        guard !target.busy else {return}
        let p=NSOpenPanel();p.canChooseFiles=true;p.canChooseDirectories=false;p.allowedContentTypes=[.applicationBundle]
        guard p.runModal() == .OK,let url=p.url,Bundle(url:url)?.bundleIdentifier != nil else {return}
        target.selectApplication(at:url);lastTargetPointer=nil;apps.selectItem(at:0);refresh()
    }
    @objc func preset() {
        let values=["CLICK 1 1","CLICK 1 2","CLICK 2 1","SCROLL -3","SCROLL 3","DRAG 0 240 500","MOVE 0 0"]
        entry.stringValue=values[presets.indexOfSelectedItem]
    }
    @objc func connect() {guard !preview else {return};UserDefaults.standard.set(name.stringValue,forKey:"DeviceName");bridge.connect(name.stringValue)}
    @objc func arm() {guard !preview else {return};bridge.submit(.arm) { [weak self] r in self?.detail.stringValue=describe(r);self?.refresh() }}
    @objc func prepare() {guard !preview else {return};target.prepare { [weak self] r in self?.detail.stringValue=describe(r);self?.refresh() };refresh()}
    @objc func send() {
        guard !preview,let command=MouseCommand.parse(entry.stringValue),command.needsArm else {detail.stringValue="Enter a valid bounded mouse command.";return}
        let v=coordinates.stringValue.split(whereSeparator:{$0.isWhitespace})
        guard v.count==2,let x=Double(v[0]),let y=Double(v[1]) else {detail.stringValue="Enter X Y percentages, for example 50 50.";return}
        append("Action requested: \(command.text) at \(x)% / \(y)%")
        target.perform(command,at:CGPoint(x:x/100,y:y/100)) { [weak self] r in self?.detail.stringValue=describe(r);self?.append(describe(r));self?.refresh() };refresh()
    }
    @objc func sendHere() {
        guard let p=lastTargetPointer,let b=target.windowBounds(),b==lastTargetPointerBounds,b.insetBy(dx:4,dy:4).contains(p),ProcessInfo.processInfo.systemUptime-lastTargetPointerTime<30 else {
            detail.stringValue="Move the pointer inside the focused target first, then return here within 30 seconds.";return
        }
        coordinates.stringValue=String(format:"%.3f %.3f",(p.x-b.minX)/b.width*100,(p.y-b.minY)/b.height*100)
        detail.stringValue="Target pointer copied to X/Y %. Confirm its control, then Position + send."
    }
    @objc func stop() {target.cancel();bridge.stop();refresh()}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        ticker?.invalidate();target.cancel();if preview {return .terminateNow}
        DispatchQueue.main.async {self.bridge.stop {NSApp.reply(toApplicationShouldTerminate:true)}};return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
