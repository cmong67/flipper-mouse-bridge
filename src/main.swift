import AppKit
import Darwin
import UniformTypeIdentifiers

func describe(_ result:Result<String,BridgeError>)->String {
    switch result { case let .success(text):return text;case let .failure(error):return "Error: \(error)" }
}

if CommandLine.arguments.contains("--self-test") {
    supportTests();PointerMath.tests()
    for value:UInt64 in [0,1,127,128,16383,16384,UInt64.max] {let bytes=varint(value);var i=0;precondition(readVarint(bytes,&i)==value && i==bytes.count)}
    var i=0;precondition(readVarint([128],&i)==nil && i==0)
    let decoded=fields(number(1,7)+field(65,field(1,Array("DRAG 120 0 1000".utf8))))
    precondition(numeric(decoded[1])==7 && fields(decoded[65]!)[1]==Array("DRAG 120 0 1000".utf8))
    precondition(fields(Array(field(1,[1,2,3]).dropLast())).isEmpty)
    print("PASS: RPC boundaries, partial frames, nested payload and truncation");exit(0)
}
if let index=CommandLine.arguments.firstIndex(of:"--render-dashboard"),CommandLine.arguments.count>index+1 {
    let app=NSApplication.shared;app.setActivationPolicy(.prohibited)
    let panel=ControlPanel(preview:true,renderOnly:true);panel.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
    let view=panel.window.contentView!;view.layoutSubtreeIfNeeded();view.displayIfNeeded()
    guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else {exit(3)}
    view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let data=bitmap.representation(using:.png,properties:[:]) else {exit(3)}
    do {try data.write(to:URL(fileURLWithPath:CommandLine.arguments[index+1]))} catch {fputs("Render failed: \(error)\n",stderr);exit(3)}
    print("Rendered read-only dashboard without activating a window or sending input.");exit(0)
}
let preview=CommandLine.arguments.contains("--dashboard-preview")
var owner:SessionOwner?
if !preview {do {owner=try SessionOwner()} catch {fputs("\(error)\n",stderr);exit(2)}}
let gui = !CommandLine.arguments.contains("--cli")
let bridge:MouseBridge
var panel:ControlPanel?
var cliTarget:TargetController?
if gui {
    let app=NSApplication.shared;panel=ControlPanel(preview:preview);app.delegate=panel;app.setActivationPolicy(.regular);bridge=panel!.bridge
} else {
    NSApplication.shared.setActivationPolicy(.accessory)
    bridge=MouseBridge();cliTarget=TargetController(bridge:bridge)
    bridge.onState={state,_ in if state != .armed {cliTarget?.cancel()}}
    bridge.connect(CommandLine.arguments.dropFirst().first{!$0.hasPrefix("--")} ?? "Flipper")
    DispatchQueue.global().async {
        while let line=readLine() {
            DispatchQueue.main.async {
                let words=line.split(whereSeparator:{$0.isWhitespace});let verb=words.first?.uppercased() ?? ""
                if ["STOP","QUIT","RELEASE"].contains(verb) {cliTarget?.cancel();bridge.stop {exit(0)};return}
                if verb=="DISCONNECT" {cliTarget?.cancel();bridge.stop {print("Disconnected.");fflush(stdout)};return}
                if verb=="CONNECT" {bridge.connect(words.dropFirst().joined(separator:" "));return}
                if verb=="TARGET",words.count==2 {
                    let token=String(words[1]);let matches=NSWorkspace.shared.runningApplications.filter {app in
                        if let pid=Int32(token) {return app.processIdentifier==pid};return app.bundleIdentifier==token
                    }
                    guard matches.count==1,let app=matches.first,app.processIdentifier != getpid() else {print("Error: TARGET needs one exact running PID or unique bundle ID.");fflush(stdout);return}
                    cliTarget?.select(app);print("Selected \(cliTarget!.targetName) PID \(app.processIdentifier)");fflush(stdout);return
                }
                if verb=="APPLICATION" {
                    let path=line.dropFirst("APPLICATION".count).trimmingCharacters(in:.whitespaces)
                    let url=URL(fileURLWithPath:path)
                    guard Bundle(url:url)?.bundleIdentifier != nil else {print("Error: application path required.");fflush(stdout);return}
                    cliTarget?.selectApplication(at:url);print("Application selected.");fflush(stdout);return
                }
                if verb=="PREPARE" {cliTarget?.prepare {print(describe($0));fflush(stdout)};return}
                if verb=="ACTION",words.count>=4,let x=Double(words[1]),let y=Double(words[2]),let command=MouseCommand.parse(words.dropFirst(3).joined(separator:" ")),command.needsArm {cliTarget?.perform(command,at:CGPoint(x:x/100,y:y/100)) {print(describe($0));fflush(stdout)};return}
                if verb=="POINT",words.count==3,let x=Double(words[1]),let y=Double(words[2]),x.isFinite,y.isFinite {cliTarget?.point(CGPoint(x:x,y:y)) {print(describe($0));fflush(stdout)};return}
                if verb=="STATUS" {print("\(bridge.state.rawValue); target: \(cliTarget!.targetName); focus: \(cliTarget!.hasFocus); pointer: \(String(describing:CGEvent(source:nil)?.location)); window: \(String(describing:cliTarget!.windowBounds())); queue: \(bridge.queuedCount); active: \(bridge.activeCommand ?? "none")");fflush(stdout);return}
                let commandText=verb=="HERE" ? words.dropFirst().joined(separator:" ") : line
                guard let command=MouseCommand.parse(commandText) else {print("Error: invalid command or bounds.");fflush(stdout);return}
                if command.needsArm {
                    guard let t=cliTarget,t.hasFocus,let b=t.windowBounds(),let p=CGEvent(source:nil)?.location else {print("Error: selected target must be focused; use TARGET then PREPARE.");fflush(stdout);return}
                    t.perform(command,at:CGPoint(x:(p.x-b.minX)/b.width,y:(p.y-b.minY)/b.height)) {print(describe($0));fflush(stdout)}
                } else {bridge.submit(command) {print(describe($0));fflush(stdout)}}
            }
        }
        DispatchQueue.main.async {cliTarget?.cancel();bridge.stop {exit(0)}}
    }
}
signal(SIGINT,SIG_IGN);signal(SIGTERM,SIG_IGN)
let signals=[SIGINT,SIGTERM].map {value -> DispatchSourceSignal in
    let source=DispatchSource.makeSignalSource(signal:value,queue:.main)
    source.setEventHandler {cliTarget?.cancel();panel?.target.cancel();bridge.stop {exit(0)}};source.resume();return source
}
if gui {NSApplication.shared.run()} else {RunLoop.main.run()}
