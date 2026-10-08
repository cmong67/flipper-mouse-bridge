import AppKit
import CoreGraphics

// App selection/focus and pointer observation are local. Pointer actions use USB HID only.
final class TargetController {
    let bridge: MouseBridge
    private var generation=0
    private(set) var busy=false
    private(set) var prepared=false
    private(set) var selectedPID: pid_t?
    private(set) var applicationURL: URL?
    private var axisGain=CGPoint(x:2.8,y:2.8)
    var onStatus: ((String)->Void)?
    init(bridge:MouseBridge) { self.bridge=bridge }
    var focusedApp: NSRunningApplication? {
        guard let pid=selectedPID else { return nil }
        return NSRunningApplication(processIdentifier:pid).flatMap { $0.isTerminated ? nil : $0 }
    }
    var targetName:String { focusedApp?.localizedName ?? applicationURL?.deletingPathExtension().lastPathComponent ?? "No app selected" }
    var hasFocus:Bool { selectedPID != nil && NSWorkspace.shared.frontmostApplication?.processIdentifier==selectedPID }
    func select(_ app:NSRunningApplication) {
        cancel();axisGain=CGPoint(x:2.8,y:2.8);selectedPID=app.processIdentifier;applicationURL=app.bundleURL
        onStatus?("Selected \(targetName) · PID \(app.processIdentifier)")
    }
    func selectApplication(at url:URL) {
        cancel();axisGain=CGPoint(x:2.8,y:2.8);selectedPID=nil;applicationURL=url
        onStatus?("Selected \(targetName); Prepare will launch it if needed.")
    }
    private func focus(_ app:NSRunningApplication) {
        if hasFocus { return }
        let controller=NSApplication.shared
        controller.activate(ignoringOtherApps:true)
        if #available(macOS 14.0,*) {
            controller.yieldActivation(to:app)
            _=app.activate(from:.current,options:[])
        } else { _=app.activate(options:[.activateIgnoringOtherApps]) }
    }
    func cancel() { generation+=1;busy=false;prepared=false }
    private func begin(_ completion:@escaping Completion)->Int? {
        guard !busy else { completion(.failure(.message("A target action is already running.")));return nil }
        guard bridge.isArmed else { completion(.failure(.message("Enable the mouse for this session first.")));return nil }
        generation+=1;busy=true;return generation
    }
    private func finish(_ id:Int,_ result:Result<String,BridgeError>,_ completion:@escaping Completion) {
        guard id==generation else { return };busy=false
        if case .failure=result { prepared=false }
        completion(result)
    }
    func windowBounds()->CGRect? {
        guard let app=focusedApp,let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return nil }
        // Frontmost visible window, rather than the largest background window for this PID.
        return windows.compactMap { info -> CGRect? in
            guard (info[kCGWindowOwnerPID as String] as? Int32)==app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int)==0,
                  let value=info[kCGWindowBounds as String] as? [String:Any],
                  let rect=CGRect(dictionaryRepresentation:value as CFDictionary),rect.width>80,rect.height>80 else { return nil }
            return rect
        }.first
    }
    func prepare(completion:@escaping Completion) {
        guard let id=begin(completion) else { return }
        prepared=false;onStatus?("Preparing \(targetName)…")
        if let app=focusedApp { focus(app);waitForWindow(id,deadline:ProcessInfo.processInfo.systemUptime+5,completion:completion);return }
        guard let url=applicationURL,Bundle(url:url)?.bundleIdentifier != nil else {
            finish(id,.failure(.message("Select a running app or choose an application first.")),completion);return
        }
        // Match the selected installation, not an ambiguous bundle-ID search.
        if let app=NSWorkspace.shared.runningApplications.first(where:{$0.bundleURL?.standardizedFileURL==url.standardizedFileURL && !$0.isTerminated}) {
            selectedPID=app.processIdentifier;focus(app);waitForWindow(id,deadline:ProcessInfo.processInfo.systemUptime+5,completion:completion);return
        }
        let config=NSWorkspace.OpenConfiguration();config.activates=true
        NSWorkspace.shared.openApplication(at:url,configuration:config) { [weak self] app,error in
            DispatchQueue.main.async {
                guard let self,id==self.generation else { return }
                guard let app,error==nil else { self.finish(id,.failure(.message("Launch failed: \(error?.localizedDescription ?? "unknown error")")),completion);return }
                self.selectedPID=app.processIdentifier;self.focus(app)
                self.waitForWindow(id,deadline:ProcessInfo.processInfo.systemUptime+15,completion:completion)
            }
        }
    }
    private func waitForWindow(_ id:Int,deadline:TimeInterval,completion:@escaping Completion) {
        guard id==generation else { return }
        guard bridge.isArmed else { finish(id,.failure(.message("Bridge disconnected during preparation.")),completion);return }
        if hasFocus,let bounds=windowBounds() {
            // Preparation verifies focus and geometry without an unnecessary center movement.
            prepared=true;finish(id,.success("\(targetName) ready · \(Int(bounds.width)) × \(Int(bounds.height)) points. Confirm the visible control before sending."),completion);return
        }
        guard ProcessInfo.processInfo.systemUptime<deadline else {
            finish(id,.failure(.message("Selected app did not expose a focused visible window. Check its Space and permissions, then select the exact running app.")),completion);return
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { [weak self] in self?.waitForWindow(id,deadline:deadline,completion:completion) }
    }
    private func guarded(_ bounds:CGRect)->Bool {
        guard bridge.isArmed,hasFocus,let current=windowBounds() else { return false }
        return abs(current.minX-bounds.minX)<2 && abs(current.minY-bounds.minY)<2 && abs(current.width-bounds.width)<2 && abs(current.height-bounds.height)<2
    }
    func perform(_ command:MouseCommand,at relative:CGPoint,completion:@escaping Completion) {
        guard relative.x.isFinite,relative.y.isFinite,(0...1).contains(relative.x),(0...1).contains(relative.y) else { completion(.failure(.message("Target percentages must be between 0 and 100.")));return }
        guard let id=begin(completion) else { return }
        guard let app=focusedApp else { finish(id,.failure(.message("Select and prepare a target app first.")),completion);return }
        focus(app)
        func check(_ deadline:TimeInterval) {
            guard id==self.generation else { return }
            if self.hasFocus,let bounds=self.windowBounds() {
                let point=CGPoint(x:bounds.minX+bounds.width*relative.x,y:bounds.minY+bounds.height*relative.y)
                guard bounds.insetBy(dx:4,dy:4).contains(point) else { self.finish(id,.failure(.message("Target is too close to the window edge.")),completion);return }
                self.move(point,in:bounds,id:id,deadline:ProcessInfo.processInfo.systemUptime+8,attempt:0,start:ProcessInfo.processInfo.systemUptime) { [weak self] result in
                    guard let self,id==self.generation else { return }
                    guard self.guarded(bounds) else { self.finish(id,.failure(.message("Focus/window changed before the action; no action sent.")),completion);return }
                    if case let .failure(error)=result { self.finish(id,.failure(error),completion);return }
                    // MOVE 0 0 is a local guarded position check; no redundant BLE round trip.
                    if command == .move(0,0) { self.finish(id,result,completion);return }
                    self.bridge.submit(command,validWhen:{ [weak self] in self?.generation==id && self?.guarded(bounds)==true && CGEvent(source:nil).map { hypot($0.location.x-point.x,$0.location.y-point.y)<=4 }==true }) { [weak self] result in self?.finish(id,result,completion) }
                };return
            }
            guard ProcessInfo.processInfo.systemUptime<deadline else { self.finish(id,.failure(.message("Target focus/window unavailable; no action sent.")),completion);return }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { check(deadline) }
        }
        check(ProcessInfo.processInfo.systemUptime+3)
    }
    func point(_ point:CGPoint,completion:@escaping Completion) {
        guard hasFocus,let bounds=windowBounds(),bounds.insetBy(dx:4,dy:4).contains(point) else { completion(.failure(.message("The selected app must be focused and the point inside its window.")));return }
        guard let id=begin(completion) else { return }
        move(point,in:bounds,id:id,deadline:ProcessInfo.processInfo.systemUptime+8,attempt:0,start:ProcessInfo.processInfo.systemUptime) { [weak self] result in self?.finish(id,result,completion) }
    }
    private func move(_ target:CGPoint,in bounds:CGRect,id:Int,deadline:TimeInterval,attempt:Int,start:TimeInterval,completion:@escaping Completion) {
        guard id==generation else { return }
        guard guarded(bounds) else { completion(.failure(.message("Focus/window geometry changed; positioning cancelled.")));return }
        guard let pointer=CGEvent(source:nil)?.location else { completion(.failure(.message("Cannot observe mouse position.")));return }
        let dx=target.x-pointer.x,dy=target.y-pointer.y,error=hypot(dx,dy)
        if error<=4 { completion(.success(String(format:"Position error %.2f pt · %d moves · %.3f s",error,attempt,ProcessInfo.processInfo.systemUptime-start)));return }
        guard attempt<32,ProcessInfo.processInfo.systemUptime<deadline else { completion(.failure(.message("Positioning timed out. No click sent.")));return }
        let x=PointerMath.step(dx,gain:abs(dx)>120 ? axisGain.x : 2.2),y=PointerMath.step(dy,gain:abs(dy)>120 ? axisGain.y : 2.2)
        bridge.submit(.move(x,y),validWhen:{ [weak self] in self?.generation==id && self?.guarded(bounds)==true }) { [weak self] result in
            guard let self,id==self.generation else { return }
            if case let .failure(error)=result { completion(.failure(error));return }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.05) { [weak self] in
                guard let self,id==self.generation else { return }
                if let after=CGEvent(source:nil)?.location {
                    self.axisGain.x=PointerMath.updatedGain(self.axisGain.x,report:x,observed:after.x-pointer.x)
                    self.axisGain.y=PointerMath.updatedGain(self.axisGain.y,report:y,observed:after.y-pointer.y)
                }
                self.move(target,in:bounds,id:id,deadline:deadline,attempt:attempt+1,start:start,completion:completion)
            }
        }
    }
}

enum PointerMath {
    static func step(_ delta:Double,gain:Double)->Int { max(-127,min(127,Int((delta/max(1,gain)).rounded()))) }
    static func updatedGain(_ old:Double,report:Int,observed:Double)->Double {
        guard abs(report)>=32,observed.isFinite,observed*Double(report)>0 else { return old }
        let sample=abs(observed/Double(report))
        guard (0.5...8).contains(sample) else { return old }
        return max(2.2,min(6,old*0.65+sample*0.35))
    }
    static func tests() {
        precondition(step(2000,gain:2.8)==127 && step(-2000,gain:2.8) == -127)
        precondition(step(3,gain:2)==2)
        precondition(updatedGain(2.8,report:0,observed:100)==2.8)
        precondition(updatedGain(2.8,report:40,observed:-80)==2.8)
        precondition(updatedGain(2.8,report:40,observed:120)>2.8)
        print("PASS: bounded adaptive pointer steps and invalid feedback rejection")
    }
}
