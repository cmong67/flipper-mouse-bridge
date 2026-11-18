import Foundation

// One dashboard request in flight; each transport preserves its own framing.
final class DeviceLink {
    var onLine:((String)->Void)?
    var onFailure:((String)->Void)?
    var onReady:(()->Void)?
    private let serial=SerialLink()
    private let flipper=MouseBridge()
    private var closing=false
    private(set) var isFlipper=false
    private var owner:SessionOwner?
    init() {
        serial.onLine={[weak self] in self?.onLine?($0)}
        serial.onFailure={[weak self] in self?.onFailure?($0)}
        flipper.onState={[weak self] state,detail in
            guard let self,!self.closing else{return}
            if state == .ready && !self.ready {self.ready=true;self.onReady?()}
            if state == .failed || state == .disconnected {self.ready=false;self.onFailure?(detail.isEmpty ? "Flipper disconnected":detail)}
        }
    }
    private var ready=false
    func connect(_ path:String) throws {
        closeLink();closing=false
        owner=try SessionOwner()
        isFlipper=path.hasPrefix("flipper://")
        if isFlipper {flipper.connect(String(path.dropFirst(10)))}
        else {try serial.connect(path);ready=true;onReady?()}
    }
    func closeLink() {
        closing=true;ready=false;serial.closeLink()
        if isFlipper {flipper.stop {[weak self] in self?.owner=nil}}
        else {owner=nil}
    }
    func poll() {if !isFlipper {serial.poll()}}
    @discardableResult func write(_ text:String)->Bool {
        guard isFlipper else{return serial.write(text)}
        guard ready,let command=FlipperCommands.translate(text) else {
            onLine?("ERR unsupported Flipper command or bounds");return true
        }
        let verb=text.split(separator:" ").first.map(String.init) ?? ""
        flipper.submit(command) {[weak self] result in
            guard let self,!self.closing else{return}
            switch result {
            case let .failure(error):self.onLine?("ERR "+error.description)
            case let .success(reply):
                if verb=="info" {self.onLine?(reply)}
                else if verb=="status" {self.onLine?(reply)}
                else {self.onLine?("OK "+(verb=="ping" ? "PONG":verb=="arm" ? "ARMED":verb.uppercased()))}
            }
        }
        return true
    }
}
