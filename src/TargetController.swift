import AppKit
import CoreGraphics

// Observation and application activation only. Every pointer action goes through USB HID.
final class TargetController {
    static let bundleID="com.run.tower.defense"
    let bridge: MouseBridge
    private var generation=0
    private(set) var busy=false
    private(set) var prepared=false
    var onStatus: ((String)->Void)?
    init(bridge:MouseBridge) { self.bridge=bridge }
    var focusedApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier==Self.bundleID && !$0.isTerminated }
    }
    var hasFocus: Bool { NSWorkspace.shared.frontmostApplication?.bundleIdentifier==Self.bundleID }
    private func focus(_ app:NSRunningApplication) {
        let controller=NSApplication.shared
        controller.activate(ignoringOtherApps:true)
        if #available(macOS 14.0,*) {
            controller.yieldActivation(to:app)
            _=app.activate(from:.current,options:[])
        } else { _=app.activate(options:[.activateIgnoringOtherApps]) }
    }
    func cancel() { generation+=1;busy=false;prepared=false }
    private func begin(_ completion:@escaping Completion) -> Int? {
        guard !busy else { completion(.failure(.message("A positioning task is already running.")));return nil }
        guard bridge.isArmed else { completion(.failure(.message("Arm the bridge before preparing Kingshot.")));return nil }
        generation+=1;busy=true;return generation
    }
    private func finish(_ id:Int,_ result:Result<String,BridgeError>,_ completion:@escaping Completion) {
        guard id==generation else { return };busy=false
        if case .failure=result { prepared=false }
        completion(result)
    }
    func windowBounds() -> CGRect? {
        guard let app=focusedApp,let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return nil }
        return windows.compactMap { info -> CGRect? in
            guard (info[kCGWindowOwnerPID as String] as? Int32)==app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int)==0,
                  let value=info[kCGWindowBounds as String] as? [String:Any],
                  let rect=CGRect(dictionaryRepresentation:value as CFDictionary),rect.width>200,rect.height>200 else { return nil }
            return rect
        }.max(by:{$0.width*$0.height < $1.width*$1.height})
    }
    func prepare(completion:@escaping Completion) {
        guard let id=begin(completion) else { return }
        prepared=false;onStatus?("Opening and focusing Kingshot…")
        if let app=focusedApp {
            focus(app);waitForWindow(id,deadline:ProcessInfo.processInfo.systemUptime+20,completion:completion);return
        }
        let saved=UserDefaults.standard.string(forKey:"KingshotPath").map { URL(fileURLWithPath:$0) }
        guard let url=NSWorkspace.shared.urlForApplication(withBundleIdentifier:Self.bundleID) ?? saved,
              Bundle(url:url)?.bundleIdentifier==Self.bundleID else {
            finish(id,.failure(.message("Kingshot could not be located. Choose its application in Settings.")),completion);return
        }
        let config=NSWorkspace.OpenConfiguration();config.activates=true
        NSWorkspace.shared.openApplication(at:url,configuration:config) { [weak self] app,error in
            DispatchQueue.main.async {
                guard let self,id==self.generation else { return }
                guard let app,error==nil else { self.finish(id,.failure(.message("Kingshot launch failed: \(error?.localizedDescription ?? "unknown error")")),completion);return }
                self.focus(app);self.waitForWindow(id,deadline:ProcessInfo.processInfo.systemUptime+20,completion:completion)
            }
        }
    }
    private func waitForWindow(_ id:Int,deadline:TimeInterval,completion:@escaping Completion) {
        guard id==generation else { return }
        guard bridge.isArmed else { finish(id,.failure(.message("Bridge disconnected during preparation.")),completion);return }
        if hasFocus,let bounds=windowBounds() {
            let point=CGPoint(x:bounds.midX,y:bounds.midY)
            move(point,in:bounds,id:id,deadline:ProcessInfo.processInfo.systemUptime+8,attempt:0,start:ProcessInfo.processInfo.systemUptime) { [weak self] result in
                guard let self,id==self.generation else { return }
                if case .success=result { self.prepared=true }
                self.finish(id,result.map { "Kingshot focused; cursor positioned. Check the screen has finished loading before selecting a control. \($0)" },completion)
            };return
        }
        guard ProcessInfo.processInfo.systemUptime < deadline else { finish(id,.failure(.message("Kingshot did not become the focused visible window within 20 seconds.")),completion);return }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.15) { [weak self] in self?.waitForWindow(id,deadline:deadline,completion:completion) }
    }
    func perform(_ command:MouseCommand,at relative:CGPoint,completion:@escaping Completion) {
        guard relative.x.isFinite,relative.y.isFinite,(0...1).contains(relative.x),(0...1).contains(relative.y) else { completion(.failure(.message("Target percentages must be between 0 and 100.")));return }
        guard let id=begin(completion) else { return }
        guard let app=focusedApp else { finish(id,.failure(.message("Prepare Kingshot first.")),completion);return }
        focus(app)
        func check(_ deadline:TimeInterval) {
            guard id==self.generation else { return }
            if self.hasFocus,let bounds=self.windowBounds() {
                let point=CGPoint(x:bounds.minX+bounds.width*relative.x,y:bounds.minY+bounds.height*relative.y)
                guard bounds.insetBy(dx:4,dy:4).contains(point) else { self.finish(id,.failure(.message("Target is too close to the window edge.")),completion);return }
                self.move(point,in:bounds,id:id,deadline:ProcessInfo.processInfo.systemUptime+8,attempt:0,start:ProcessInfo.processInfo.systemUptime) { [weak self] result in
                    guard let self,id==self.generation else { return }
                    if case let .failure(error)=result { self.finish(id,.failure(error),completion);return }
                    self.bridge.submit(command) { [weak self] result in self?.finish(id,result,completion) }
                };return
            }
            guard ProcessInfo.processInfo.systemUptime<deadline else { self.finish(id,.failure(.message("Kingshot focus or pointer location could not be verified. Prepare or POINT first.")),completion);return }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { check(deadline) }
        }
        check(ProcessInfo.processInfo.systemUptime+2)
    }
    func point(_ point:CGPoint,completion:@escaping Completion) {
        guard hasFocus,let bounds=windowBounds(),bounds.insetBy(dx:4,dy:4).contains(point) else { completion(.failure(.message("Kingshot must be focused and the target must be inside its current window.")));return }
        guard let id=begin(completion) else { return }
        move(point,in:bounds,id:id,deadline:ProcessInfo.processInfo.systemUptime+8,attempt:0,start:ProcessInfo.processInfo.systemUptime) { [weak self] result in self?.finish(id,result,completion) }
    }
    private func move(_ target:CGPoint,in bounds:CGRect,id:Int,deadline:TimeInterval,attempt:Int,start:TimeInterval,completion:@escaping Completion) {
        guard id==generation else { return }
        guard bridge.isArmed,hasFocus,let current=windowBounds(),abs(current.origin.x-bounds.origin.x)<2,abs(current.origin.y-bounds.origin.y)<2,abs(current.width-bounds.width)<2,abs(current.height-bounds.height)<2 else {
            completion(.failure(.message("Focus or window geometry changed; positioning cancelled.")));return
        }
        guard let pointer=CGEvent(source:nil)?.location else { completion(.failure(.message("Cannot observe mouse position.")));return }
        let dx=target.x-pointer.x,dy=target.y-pointer.y,error=hypot(dx,dy)
        if error<=4 {
            completion(.success(String(format:"Position error %.2f points; %d moves; %.3f seconds.",error,attempt,ProcessInfo.processInfo.systemUptime-start)));return
        }
        guard attempt<32,ProcessInfo.processInfo.systemUptime<deadline else { completion(.failure(.message("Positioning timed out. No click was sent.")));return }
        let gain=attempt<3 ? 2.8 : 2.2
        let x=max(-127,min(127,Int((dx/gain).rounded()))),y=max(-127,min(127,Int((dy/gain).rounded())))
        bridge.submit(.move(x,y)) { [weak self] result in
            guard let self,id==self.generation else { return }
            if case let .failure(error)=result { completion(.failure(error));return }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { [weak self] in
                self?.move(target,in:bounds,id:id,deadline:deadline,attempt:attempt+1,start:start,completion:completion)
            }
        }
    }
}
