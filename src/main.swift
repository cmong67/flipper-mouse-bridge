import AppKit
import Darwin
import UniformTypeIdentifiers

func describe(_ result:Result<String,BridgeError>) -> String {
    switch result { case let .success(text): return text;case let .failure(error):return "Error: \(error)" }
}
final class ControlPanel:NSObject,NSApplicationDelegate {
    let bridge=MouseBridge()
    lazy var target=TargetController(bridge:bridge)
    var window:NSWindow!
    let name=NSTextField(string:UserDefaults.standard.string(forKey:"DeviceName") ?? "Flipper")
    let status=NSTextField(wrappingLabelWithString:"Disconnected")
    let detail=NSTextField(wrappingLabelWithString:"Connect, arm, then prepare Kingshot. USB carries the mouse input; Bluetooth carries commands.")
    let entry=NSTextField(string:"MOVE 0 0")
    let coordinates=NSTextField(string:"50 50")
    let connectButton=NSButton(title:"Connect",target:nil,action:nil)
    let armButton=NSButton(title:"Enable mouse",target:nil,action:nil)
    let prepareButton=NSButton(title:"Prepare Kingshot",target:nil,action:nil)
    let sendButton=NSButton(title:"Send to Kingshot",target:nil,action:nil)
    let stopButton=NSButton(title:"Stop",target:nil,action:nil)
    let logView=NSTextView()
    var lines=[String]()
    func applicationDidFinishLaunching(_ notification:Notification) {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:660,height:480),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="Flipper Mouse Bridge 0.2";window.center()
        let view=window.contentView!
        status.frame=NSRect(x:20,y:420,width:620,height:35);status.font=NSFont.boldSystemFont(ofSize:19);view.addSubview(status)
        detail.frame=NSRect(x:20,y:365,width:620,height:50);view.addSubview(detail)
        name.frame=NSRect(x:20,y:325,width:240,height:26);name.placeholderString="Distinctive Flipper name";view.addSubview(name)
        func button(_ b:NSButton,_ x:Double,_ y:Double,_ width:Double,_ action:Selector) { b.frame=NSRect(x:x,y:y,width:width,height:32);b.target=self;b.action=action;view.addSubview(b) }
        button(connectButton,275,322,110,#selector(connect));button(armButton,395,322,135,#selector(arm));button(stopButton,545,322,95,#selector(stop))
        button(prepareButton,20,280,175,#selector(prepare))
        let choose=NSButton(title:"Choose Kingshot…",target:nil,action:nil);button(choose,205,280,175,#selector(chooseGame))
        let targetLabel=NSTextField(labelWithString:"Target X/Y %:");targetLabel.frame=NSRect(x:395,y:286,width:100,height:20);view.addSubview(targetLabel)
        coordinates.frame=NSRect(x:500,y:283,width:140,height:26);view.addSubview(coordinates)
        entry.frame=NSRect(x:20,y:240,width:420,height:26);view.addSubview(entry)
        button(sendButton,450,237,190,#selector(send))
        let help=NSTextField(wrappingLabelWithString:"Target is a percentage of the current Kingshot window, from its top left. Send focuses the game, positions at that target, then runs MOVE x y · CLICK button count · SCROLL delta · DRAG x y ms. Confirm the control on screen first.")
        help.frame=NSRect(x:20,y:174,width:620,height:58);view.addSubview(help)
        let scroll=NSScrollView(frame:NSRect(x:20,y:20,width:620,height:150));scroll.hasVerticalScroller=true
        logView.isEditable=false;logView.font=NSFont.monospacedSystemFont(ofSize:11,weight:.regular);scroll.documentView=logView;view.addSubview(scroll)
        bridge.onLog={ [weak self] text in self?.append(text) }
        bridge.onState={ [weak self] state,reason in
            guard let self else { return }
            if state != .armed { self.target.cancel() }
            self.status.stringValue=state.rawValue
            if !reason.isEmpty { self.detail.stringValue=reason };self.refresh()
        }
        target.onStatus={ [weak self] text in self?.detail.stringValue=text }
        refresh();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func append(_ text:String) { lines.append(text);if lines.count>200 { lines.removeFirst(lines.count-200) };logView.string=lines.joined(separator:"\n")+"\n";logView.scrollToEndOfDocument(nil) }
    func refresh() { connectButton.isEnabled=bridge.canConnect;name.isEnabled=bridge.canConnect;armButton.isEnabled=bridge.state == .ready;prepareButton.isEnabled=bridge.isArmed && !target.busy;sendButton.isEnabled=bridge.isArmed && !target.busy;stopButton.isEnabled = !bridge.canConnect }
    @objc func connect() { UserDefaults.standard.set(name.stringValue,forKey:"DeviceName");bridge.connect(name.stringValue) }
    @objc func arm() { bridge.submit(.arm) { [weak self] result in self?.detail.stringValue=describe(result);self?.refresh() } }
    @objc func prepare() { target.prepare { [weak self] result in self?.detail.stringValue=describe(result);self?.refresh() };refresh() }
    @objc func send() {
        guard let command=MouseCommand.parse(entry.stringValue),command.needsArm else { detail.stringValue="Enter a valid bounded mouse command.";return }
        let values=coordinates.stringValue.split(whereSeparator:{$0.isWhitespace})
        guard values.count==2,let x=Double(values[0]),let y=Double(values[1]) else { detail.stringValue="Enter two target percentages, for example 50 50.";return }
        target.perform(command,at:CGPoint(x:x/100,y:y/100)) { [weak self] result in self?.detail.stringValue=describe(result);self?.refresh() };refresh()
    }
    @objc func stop() { target.cancel();bridge.stop();refresh() }
    @objc func chooseGame() {
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=false;panel.allowedContentTypes=[.applicationBundle]
        guard panel.runModal() == .OK,let url=panel.url else { return }
        guard Bundle(url:url)?.bundleIdentifier==TargetController.bundleID else { detail.stringValue="Choose the Kingshot application.";return }
        UserDefaults.standard.set(url.path,forKey:"KingshotPath");detail.stringValue="Kingshot location saved."
    }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        target.cancel();DispatchQueue.main.async { self.bridge.stop { NSApp.reply(toApplicationShouldTerminate:true) } };return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
if CommandLine.arguments.contains("--self-test") {
    supportTests()
    for value:UInt64 in [0,1,127,128,16383,16384,UInt64.max] { let bytes=varint(value);var i=0;precondition(readVarint(bytes,&i)==value && i==bytes.count) }
    var i=0;precondition(readVarint([128],&i)==nil && i==0)
    let decoded=fields(number(1,7)+field(65,field(1,Array("DRAG 120 0 1000".utf8))))
    precondition(numeric(decoded[1])==7 && fields(decoded[65]!)[1]==Array("DRAG 120 0 1000".utf8))
    precondition(fields(Array(field(1,[1,2,3]).dropLast())).isEmpty)
    print("PASS: RPC boundaries, partial frames, nested payload and truncation");exit(0)
}
var owner:SessionOwner!
do { owner=try SessionOwner() } catch { fputs("\(error)\n",stderr);exit(2) }
let gui = !CommandLine.arguments.contains("--cli")
let bridge:MouseBridge
var panel:ControlPanel?
var cliTarget:TargetController?
if gui {
    let app=NSApplication.shared;panel=ControlPanel();app.delegate=panel;app.setActivationPolicy(.regular);bridge=panel!.bridge
} else {
    NSApplication.shared.setActivationPolicy(.accessory)
    bridge=MouseBridge();cliTarget=TargetController(bridge:bridge)
    bridge.onState={ state,_ in if state != .armed { cliTarget?.cancel() } }
    bridge.connect(CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? "Flipper")
    DispatchQueue.global().async {
        while let line=readLine() {
            DispatchQueue.main.async {
                let words=line.split(whereSeparator:{$0.isWhitespace});let verb=words.first?.uppercased() ?? ""
                if ["STOP","QUIT","RELEASE"].contains(verb) { cliTarget?.cancel();bridge.stop { exit(0) };return }
                if verb=="DISCONNECT" { cliTarget?.cancel();bridge.stop { print("Disconnected.");fflush(stdout) };return }
                if verb=="CONNECT" { bridge.connect(words.dropFirst().joined(separator:" "));return }
                if verb=="PREPARE" { cliTarget?.prepare { print(describe($0));fflush(stdout) };return }
                if verb=="ACTION",words.count>=4,let x=Double(words[1]),let y=Double(words[2]),let command=MouseCommand.parse(words.dropFirst(3).joined(separator:" ")),command.needsArm { cliTarget?.perform(command,at:CGPoint(x:x/100,y:y/100)) { print(describe($0));fflush(stdout) };return }
                if verb=="POINT",words.count==3,let x=Double(words[1]),let y=Double(words[2]),x.isFinite,y.isFinite { cliTarget?.point(CGPoint(x:x,y:y)) { print(describe($0));fflush(stdout) };return }
                if verb=="STATUS" { print("\(bridge.state.rawValue); Kingshot focus: \(cliTarget?.hasFocus ?? false); pointer: \(String(describing:CGEvent(source:nil)?.location)); window: \(String(describing:cliTarget?.windowBounds()))");fflush(stdout);return }
                guard let command=MouseCommand.parse(line) else { print("Error: invalid command or bounds.");fflush(stdout);return }
                bridge.submit(command) { print(describe($0));fflush(stdout) }
            }
        }
        DispatchQueue.main.async { cliTarget?.cancel();bridge.stop { exit(0) } }
    }
}
signal(SIGINT,SIG_IGN);signal(SIGTERM,SIG_IGN)
let signals=[SIGINT,SIGTERM].map { value -> DispatchSourceSignal in
    let source=DispatchSource.makeSignalSource(signal:value,queue:.main)
    source.setEventHandler { cliTarget?.cancel();panel?.target.cancel();bridge.stop { exit(0) } };source.resume();return source
}
if gui { NSApplication.shared.run() } else { RunLoop.main.run() }
