import Foundation
import CoreBluetooth
import AppKit

func varint(_ value: UInt64) -> [UInt8] {
    var v=value; var bytes=[UInt8]()
    repeat { var b=UInt8(v & 127); v >>= 7; if v>0 { b |= 128 }; bytes.append(b) } while v>0
    return bytes
}
func field(_ number: Int, _ bytes: [UInt8]) -> [UInt8] {
    varint(UInt64(number << 3 | 2)) + varint(UInt64(bytes.count)) + bytes
}
func number(_ field: Int, _ value: UInt64) -> [UInt8] { varint(UInt64(field << 3)) + varint(value) }
func readVarint(_ bytes: [UInt8], _ index: inout Int) -> UInt64? {
    let start=index; var value: UInt64=0
    for shift in stride(from: 0, through: 63, by: 7) {
        guard index < bytes.count else { index=start; return nil }
        let b=bytes[index]; index+=1
        if shift==63 && b>1 { return nil }
        value |= UInt64(b & 127) << shift
        if b & 128 == 0 { return value }
    }
    return nil
}
func fields(_ bytes: [UInt8]) -> [Int: [UInt8]] {
    var result=[Int:[UInt8]](); var i=0
    while i<bytes.count {
        guard let key=readVarint(bytes,&i) else { break }
        let id=Int(key >> 3)
        if key & 7 == 0 {
            guard let value=readVarint(bytes,&i) else { break }; result[id]=varint(value)
        } else if key & 7 == 2 {
            guard let length=readVarint(bytes,&i), length <= UInt64(bytes.count-i) else { break }
            result[id]=Array(bytes[i..<i+Int(length)]); i+=Int(length)
        } else { break }
    }
    return result
}
func numeric(_ bytes: [UInt8]?) -> UInt64 { var i=0; return readVarint(bytes ?? [0],&i) ?? 0 }

enum BridgeState: String {
    case disconnected="Disconnected", scanning="Finding Flipper", connecting="Connecting", starting="Starting bridge", ready="Ready — mouse disabled", armed="Ready — mouse enabled", stopping="Stopping", failed="Connection failed"
}

final class MouseBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private(set) var state: BridgeState = .disconnected
    var onState: ((BridgeState,String)->Void)?
    var onLog: ((String)->Void)?
    private var manager: CBCentralManager!
    private var device: CBPeripheral?
    private var rx: CBCharacteristic?
    private var buffer=[UInt8]()
    private var nextID: UInt64=1
    private var pending: UInt64?
    private var active: QueuedCommand?
    private var response: String?
    private var commandStarted: TimeInterval?
    private(set) var completedCommands=0
    private(set) var lastCommand:String?
    private(set) var lastResult:String?
    private(set) var lastLatency: TimeInterval?
    private(set) var averageLatency: TimeInterval?
    var activeElapsed:TimeInterval? { commandStarted.map {now-$0} }
    var activeCommand:String? { active?.command.text }
    var queuedCount:Int { queue.items.count }
    private var queue=CommandQueue(limit:8)
    private var timer: DispatchWorkItem?
    private var target=""
    private var failure: String?
    private var stopCompletions=[()->Void]()
    private let txUUID=CBUUID(string:"19ED82AE-ED21-4C9D-4145-228E61FE0000")
    private let rxUUID=CBUUID(string:"19ED82AE-ED21-4C9D-4145-228E62FE0000")
    private let serviceUUID=CBUUID(string:"8FE5B3D5-2E7F-4A98-2A48-7ACC60FE0000")
    override init() { super.init() }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    var isArmed: Bool { state == .armed }
    var canConnect: Bool { state == .disconnected || state == .failed }
    private func log(_ text: String) { print(text);fflush(stdout);onLog?(text) }
    private func transition(_ value: BridgeState, _ detail: String="") {
        state=value; log("State: \(value.rawValue)\(detail.isEmpty ? "" : " · "+detail)");onState?(value,detail)
    }
    private func timeout(_ seconds: Double, _ action: @escaping ()->Void) {
        timer?.cancel();let work=DispatchWorkItem(block:action);timer=work
        DispatchQueue.main.asyncAfter(deadline:.now()+seconds,execute:work)
    }
    func connect(_ name: String) {
        guard canConnect else { log("Stop the current connection before reconnecting.");return }
        let name=name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { transition(.failed,"Enter a distinctive Flipper name.");return }
        failure=nil;target=name;rx=nil;buffer.removeAll();pending=nil;response=nil
        transition(.scanning)
        if manager==nil {manager=CBCentralManager(delegate:self,queue:.main)}
        log("Bluetooth state: \(manager.state.rawValue); authorization: \(CBManager.authorization.rawValue)")
        timeout(15) { [weak self] in
            guard let self else {return}
            self.fail(self.manager.state == .unknown || self.manager.state == .resetting ? "Bluetooth initialization did not finish. Check this app in System Settings → Privacy & Security → Bluetooth, then quit and reopen. No mouse command was sent." : "Flipper not found within 15 seconds. Check Bluetooth and device name, then reconnect.")
        }
        if manager.state == .poweredOn { scan() }
        else if manager.state != .unknown && manager.state != .resetting { fail("Bluetooth unavailable or permission denied.") }
    }
    private func scan() {
        guard let manager else {return}
        log("Bluetooth available; discovering device.")
        if let saved=UserDefaults.standard.string(forKey:"Peripheral-"+target.lowercased()),let id=UUID(uuidString:saved),let cached=manager.retrievePeripherals(withIdentifiers:[id]).first {
            centralManager(manager,didDiscover:cached,advertisementData:[:],rssi:0)
            if state != .scanning { return }
        }
        for peripheral in manager.retrieveConnectedPeripherals(withServices:[serviceUUID]) {
            centralManager(manager,didDiscover:peripheral,advertisementData:[:],rssi:0)
            if state != .scanning { return }
        }
        manager.scanForPeripherals(withServices:nil,options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { if state == .scanning { scan() } }
        else if !canConnect && state != .stopping && central.state != .unknown && central.state != .resetting {
            fail("Bluetooth unavailable. Restore Bluetooth, then reconnect and arm a fresh session.")
        }
    }
    func centralManager(_ central: CBCentralManager,didDiscover peripheral: CBPeripheral,advertisementData: [String:Any],rssi RSSI:NSNumber) {
        guard state == .scanning else { return }
        let name=advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard name.localizedCaseInsensitiveContains(target) else { return }
        UserDefaults.standard.set(peripheral.identifier.uuidString,forKey:"Peripheral-"+target.lowercased())
        device=peripheral;peripheral.delegate=self;central.stopScan();transition(.connecting)
        timeout(20) { [weak self] in self?.fail("Connection or pairing timed out. Confirm pairing on both devices, then reconnect.") }
        central.connect(peripheral)
    }
    func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral) {
        guard state == .connecting else { central.cancelPeripheralConnection(peripheral);return }
        peripheral.discoverServices([serviceUUID])
    }
    func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?) {
        guard peripheral == device else { return }
        failure="Could not connect: \(error?.localizedDescription ?? "connection refused")";finishDisconnect()
    }
    func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?) {
        guard peripheral == device else { return }
        if state != .stopping { failure="Connection lost. Reconnect and arm a fresh session." }
        finishDisconnect()
    }
    private func finishDisconnect() {
        timer?.cancel();if manager?.state == .poweredOn {manager.stopScan()};device?.delegate=nil;device=nil;rx=nil;buffer.removeAll();pending=nil;response=nil
        let old=active;active=nil;commandStarted=nil;let queued=queue.cancel()
        transition(failure == nil ? .disconnected : .failed,failure ?? "Mouse commands cleared; Flipper restores USB after disconnect.")
        old?.completion(.failure(.message("Session ended.")));queued.forEach { $0.completion(.failure(.message("Session ended; action discarded."))) }
        let callbacks=stopCompletions;stopCompletions.removeAll();callbacks.forEach { $0() }
    }
    func stop(completion: (()->Void)? = nil) {
        if let completion { stopCompletions.append(completion) }
        if state == .stopping { return }
        timer?.cancel();if manager?.state == .poweredOn {manager.stopScan()};transition(.stopping)
        let queued=queue.cancel();queued.forEach { $0.completion(.failure(.message("Stopped; action discarded."))) }
        if let device {
            manager?.cancelPeripheralConnection(device)
            // Stay unavailable until CoreBluetooth confirms disconnect. Never open a competing session.
            timeout(5) { [weak self] in self?.log("Still waiting for Bluetooth disconnect. Unplug Flipper if its mouse remains active.") }
        } else { finishDisconnect() }
    }
    private func fail(_ text:String) { failure=text;log("Error: \(text)");stop() }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        guard state == .connecting else { return }
        if let error { fail(error.localizedDescription);return }
        guard let service=peripheral.services?.first(where:{$0.uuid==serviceUUID}) else { fail("Flipper RPC service unavailable.");return }
        peripheral.discoverCharacteristics([rxUUID,txUUID],for:service)
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        guard state == .connecting else { return }
        if let error { fail(error.localizedDescription);return }
        rx=service.characteristics?.first(where:{$0.uuid==rxUUID})
        guard let tx=service.characteristics?.first(where:{$0.uuid==txUUID}), rx != nil else { fail("Flipper RPC characteristics unavailable.");return }
        log("Confirm a matching pairing code if requested.");peripheral.setNotifyValue(true,for:tx)
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateNotificationStateFor characteristic:CBCharacteristic,error:Error?) {
        guard state == .connecting else { return }
        if let error { fail("Pairing: \(error.localizedDescription)");return }
        if characteristic.uuid==txUUID && characteristic.isNotifying {
            transition(.starting)
            request(16,field(1,Array("/ext/apps/Tools/ble_usb_mouse.fap".utf8))+field(2,Array("RPC".utf8)))
        }
    }
    private func request(_ kind:Int,_ content:[UInt8]) {
        guard pending==nil,let device,let rx else { fail("RPC request unavailable.");return }
        let id=nextID;nextID+=1;pending=id
        let payload=number(1,id)+field(kind,content)
        let data=Data(varint(UInt64(payload.count))+payload)
        guard data.count <= device.maximumWriteValueLength(for:.withResponse) else { fail("Command exceeds Bluetooth write limit.");return }
        device.writeValue(data,for:rx,type:.withResponse)
        timeout(10) { [weak self] in self?.fail("Command timed out; disconnecting to release input. No action will be replayed.") }
    }
    func peripheral(_ peripheral:CBPeripheral,didWriteValueFor characteristic:CBCharacteristic,error:Error?) {
        if let error, state != .stopping { fail("Write: \(error.localizedDescription)") }
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?) {
        guard state != .stopping && !canConnect else { return }
        if let error { fail(error.localizedDescription);return }
        guard characteristic.uuid==txUUID,let data=characteristic.value else { return }
        guard buffer.count+data.count <= 131072 else { fail("RPC receive buffer exceeded limit.");return }
        buffer+=data
        while !buffer.isEmpty {
            var prefix=0
            guard let length=readVarint(buffer,&prefix) else {
                if buffer.count >= 10 { fail("Invalid RPC frame prefix.") };return
            }
            guard length <= 65536 else { fail("Invalid RPC frame length.");return }
            guard buffer.count >= prefix+Int(length) else { return }
            let message=Array(buffer[prefix..<prefix+Int(length)]);buffer.removeFirst(prefix+Int(length));receive(message)
            if state == .stopping || canConnect { return }
        }
    }
    private func receive(_ message:[UInt8]) {
        let f=fields(message),id=numeric(f[1]),status=numeric(f[2])
        if let event=f[58] {
            let appState=numeric(fields(event)[1])
            if appState==1 && state == .starting { transition(.ready);if pending==nil { timer?.cancel();pump() } }
            if appState==0 && (state == .ready || state == .armed) { failure="Flipper app stopped. Reconnect to start a fresh session.";stop();return }
        }
        if let exchange=f[65],let bytes=fields(exchange)[1],active != nil {
            response=String(decoding:bytes,as:UTF8.self)
        }
        if pending==id {
            guard status==0 else { fail("Flipper rejected RPC request (status \(status)).");return }
            pending=nil
        }
        if active != nil { finishCommandIfReady() }
        else if pending==nil && (state == .ready || state == .armed) { timer?.cancel();pump() }
    }
    private func finishCommandIfReady() {
        guard pending==nil,let result=response,let item=active else { return }
        timer?.cancel();active=nil;response=nil;lastCommand=item.command.text;lastResult=result
        if let start=commandStarted {
            let latency=now-start;lastLatency=latency;completedCommands+=1
            averageLatency=(averageLatency ?? latency)*0.8+latency*0.2
            log(String(format:"Flipper: %@ · %.0f ms",result,latency*1000))
        } else { log("Flipper: \(result)") }
        commandStarted=nil
        if result.hasPrefix("ERROR") || result=="STOPPED" {
            if item.command == .arm { transition(.ready) }
            item.completion(.failure(.message(result)))
        } else {
            if item.command == .arm {
                guard result=="ARMED" else { item.completion(.failure(.message("Unexpected ARM response.")));fail("Could not verify arming.");return }
                transition(.armed)
            }
            item.completion(.success(result))
        }
        pump()
    }
    func submit(_ command:MouseCommand,completion:@escaping Completion = { _ in }) {
        submit(command,validWhen:{true},completion:completion)
    }
    func submit(_ command:MouseCommand,validWhen:@escaping ()->Bool,completion:@escaping Completion) {
        guard state == .ready || state == .armed else { completion(.failure(.message("Connect and wait for Ready first.")));return }
        guard !command.needsArm || isArmed else { completion(.failure(.message("Mouse disabled. Arm this session first.")));return }
        guard queue.append(command,now:now,validWhen:validWhen,completion:completion) else { completion(.failure(.message("Command queue full; action rejected.")));return }
        pump()
    }
    private func pump() {
        guard (state == .ready || state == .armed),pending==nil,active==nil else { return }
        let (next,expired)=queue.next(now:now)
        expired.forEach { $0.completion(.failure(.message("Queued action expired; submit a fresh action."))) }
        guard pending==nil,active==nil,state == .ready || state == .armed,let item=next else {
            next?.completion(.failure(.message("Session changed; action discarded.")));return
        }
        guard !item.command.needsArm || isArmed else { item.completion(.failure(.message("Session is not armed.")));pump();return }
        guard item.validWhen() else {item.completion(.failure(.message("Target guard changed before dispatch; action discarded.")));pump();return}
        active=item;response=nil;commandStarted=now;log("Sending: \(item.command.text)");request(65,field(1,Array(item.command.text.utf8)))
    }
}
