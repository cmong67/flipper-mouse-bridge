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
var displayLog: ((String)->Void)?
func log(_ message: String) { print(message); fflush(stdout); displayLog?(message) }

final class MouseBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    let target: String
    var manager: CBCentralManager!
    var device: CBPeripheral?
    var rx: CBCharacteristic?
    var buffer=[UInt8]()
    var nextID: UInt64=1
    var pending: UInt64?
    var waitingResult=false
    var started=false
    var queue=[String]()
    var timeout: DispatchWorkItem?
    var exiting=false
    let txUUID=CBUUID(string:"19ED82AE-ED21-4C9D-4145-228E61FE0000")
    let rxUUID=CBUUID(string:"19ED82AE-ED21-4C9D-4145-228E62FE0000")
    let serviceUUID=CBUUID(string:"8FE5B3D5-2E7F-4A98-2A48-7ACC60FE0000")
    init(target: String) {
        self.target=target
        super.init()
        manager=CBCentralManager(delegate:self,queue:.main)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            log("Scanning for \(target)…")
            central.scanForPeripherals(withServices:nil, options:nil)
        } else { log("Bluetooth state: \(central.state.rawValue) (powered on=5, unauthorized=3)") }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String:Any], rssi RSSI: NSNumber) {
        let name=advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard name.localizedCaseInsensitiveContains(target), device == nil else { return }
        device=peripheral; peripheral.delegate=self; central.stopScan()
        log("Connecting to \(name)…"); central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager,didConnect peripheral:CBPeripheral) {
        log("Connected; discovering encrypted RPC service.")
        peripheral.discoverServices([serviceUUID])
    }
    func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?) { fail("Connection failed: \(String(describing:error))") }
    func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?) {
        log("Disconnected. Flipper will release buttons and restore USB."); exit(exiting ? 0 : 1)
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        if let error { fail(error.localizedDescription); return }
        guard let service=peripheral.services?.first else { fail("RPC service absent. Enable Flipper Bluetooth."); return }
        peripheral.discoverCharacteristics(nil,for:service)
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        if let error { fail(error.localizedDescription); return }
        rx=service.characteristics?.first(where:{$0.uuid==rxUUID})
        guard let tx=service.characteristics?.first(where:{$0.uuid==txUUID}), rx != nil else { fail("RPC characteristics absent"); return }
        log("Pairing may require matching the code on Mac and Flipper.")
        peripheral.setNotifyValue(true,for:tx)
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateNotificationStateFor characteristic:CBCharacteristic,error:Error?) {
        if let error { fail("Pairing/notifications: \(error.localizedDescription)"); return }
        if characteristic.uuid==txUUID && characteristic.isNotifying {
            log("RPC notifications ready.")
            request(16,field(1,Array("/ext/apps/Tools/ble_usb_mouse.fap".utf8))+field(2,Array("RPC".utf8)))
        }
    }
    func request(_ kind:Int,_ content:[UInt8]) {
        guard pending==nil, let device, let rx else { fail("Request already pending or disconnected"); return }
        let id=nextID; nextID+=1; pending=id
        let payload=number(1,id)+field(kind,content)
        let data=Data(varint(UInt64(payload.count))+payload)
        // Our bounded commands fit within one authenticated ATT write.
        guard data.count <= device.maximumWriteValueLength(for:.withResponse) else { fail("Command exceeds Bluetooth write limit"); return }
        device.writeValue(data,for:rx,type:.withResponse)
        armTimeout()
    }
    func armTimeout() {
        timeout?.cancel()
        let work=DispatchWorkItem { [weak self] in self?.fail("Command timed out; disconnecting to release buttons") }
        timeout=work; DispatchQueue.main.asyncAfter(deadline:.now()+10,execute:work)
    }
    func peripheral(_ peripheral:CBPeripheral,didWriteValueFor characteristic:CBCharacteristic,error:Error?) {
        if let error { fail("Write: \(error.localizedDescription)") }
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?) {
        if let error { fail(error.localizedDescription); return }
        guard characteristic.uuid==txUUID, let data=characteristic.value else { return }
        buffer+=data
        while !buffer.isEmpty {
            var prefix=0
            guard let length=readVarint(buffer,&prefix) else { return }
            guard length <= 65536 else { fail("Invalid RPC frame"); return }
            guard buffer.count >= prefix+Int(length) else { return }
            let message=Array(buffer[prefix..<prefix+Int(length)])
            buffer.removeFirst(prefix+Int(length)); receive(message)
        }
    }
    func receive(_ message:[UInt8]) {
        let f=fields(message); let id=numeric(f[1]); let status=numeric(f[2])
        if f[58] != nil {
            let state=numeric(fields(f[58]!)[1]); log("Flipper app state: \(state)")
            if state==1 { started=true; log("Bridge ready. Use ARM to enable mouse commands."); if pending==nil { timeout?.cancel(); pump() } }
            if state==0 && started { exiting=true; if let device { manager.cancelPeripheralConnection(device) } }
        }
        if let exchange=f[65], let bytes=fields(exchange)[1] {
            let response=String(decoding:bytes,as:UTF8.self); log("Flipper: \(response)")
            waitingResult=false
            if pending==nil { timeout?.cancel(); pump() }
        }
        if pending==id {
            if status != 0 { fail("Flipper rejected request (status \(status))"); return }
            pending=nil
            if !started { armTimeout(); return }
            if !waitingResult { timeout?.cancel(); pump() }
        }
    }
    func submit(_ text:String) {
        let command=text.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
        guard !command.isEmpty else { return }
        if command=="QUIT" || command=="STOP" || command=="RELEASE" {
            exiting=true
            log("Stopping by disconnecting the Bluetooth control channel.")
            if let device { manager.cancelPeripheralConnection(device) } else { exit(0) }
            return
        }
        guard command.utf8.count<96 else { log("Command too long"); return }
        queue.append(command); pump()
    }
    func pump() {
        guard started, pending==nil, !waitingResult, !queue.isEmpty else { return }
        let command=queue.removeFirst(); log("Sending: \(command)")
        waitingResult=true
        request(65,field(1,Array(command.utf8)))
    }
    func fail(_ message:String) {
        log("ERROR: \(message)")
        queue.removeAll(); timeout?.cancel()
        if let device { manager.cancelPeripheralConnection(device) }
        DispatchQueue.main.asyncAfter(deadline:.now()+1) { exit(1) }
    }
}
final class ControlPanel: NSObject, NSApplicationDelegate {
    var bridge: MouseBridge!
    var window: NSWindow!
    let entry=NSTextField(string:"PING")
    let status=NSTextField(wrappingLabelWithString:"Starting Bluetooth…")
    let logView=NSTextView()
    var scheduled: DispatchWorkItem?
    func applicationDidFinishLaunching(_ notification:Notification) {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:650,height:460),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="Flipper Mouse Bridge"; window.center()
        let view=window.contentView!
        status.frame=NSRect(x:20,y:390,width:610,height:50); view.addSubview(status)
        let help=NSTextField(wrappingLabelWithString:"USB cable + Bluetooth. Start with ARM. Commands: MOVE x y · CLICK button count (1 left, 2 right, 4 middle) · SCROLL delta · DRAG x y ms. BACK on Flipper stops and releases. Mouse commands wait 3 seconds so you can focus the target window.")
        help.frame=NSRect(x:20,y:320,width:610,height:65); view.addSubview(help)
        entry.frame=NSRect(x:20,y:280,width:430,height:28); entry.target=self; entry.action=#selector(send); view.addSubview(entry)
        let sendButton=NSButton(title:"Send",target:self,action:#selector(send)); sendButton.frame=NSRect(x:460,y:278,width:75,height:32); view.addSubview(sendButton)
        let stop=NSButton(title:"Stop",target:self,action:#selector(stop)); stop.frame=NSRect(x:545,y:278,width:80,height:32); view.addSubview(stop)
        let scroll=NSScrollView(frame:NSRect(x:20,y:20,width:610,height:245)); scroll.hasVerticalScroller=true
        logView.isEditable=false; logView.font=NSFont.monospacedSystemFont(ofSize:12,weight:.regular); scroll.documentView=logView; view.addSubview(scroll)
        displayLog={ [weak self] message in
            guard let self else { return }; self.status.stringValue=message
            self.logView.string += message+"\n"; self.logView.scrollToEndOfDocument(nil)
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        bridge=MouseBridge(target:CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("--") }) ?? "Flipper")
    }
    @objc func send() {
        let command=entry.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
        scheduled?.cancel()
        if command=="STOP" || command=="RELEASE" || command=="QUIT" { stop(); return }
        if command=="PING" || command=="ARM" { bridge.submit(command); return }
        log("Sending in 3 seconds: \(command). Focus the target window now.")
        let work=DispatchWorkItem { [weak self] in self?.bridge.submit(command) }
        scheduled=work; DispatchQueue.main.asyncAfter(deadline:.now()+3,execute:work)
    }
    @objc func stop() { scheduled?.cancel(); bridge.submit("STOP") }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply { scheduled?.cancel(); bridge?.submit("STOP"); return .terminateCancel }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
if CommandLine.arguments.contains("--self-test") {
    for value: UInt64 in [0,1,127,128,16383,16384,UInt64.max] {
        let encoded=varint(value); var i=0
        precondition(readVarint(encoded,&i)==value && i==encoded.count)
    }
    var index=0
    precondition(readVarint([128],&index)==nil && index==0)
    let payload=number(1,7)+field(65,field(1,Array("DRAG 120 0 1000".utf8)))
    let decoded=fields(payload)
    precondition(numeric(decoded[1])==7)
    precondition(fields(decoded[65]!)[1]==Array("DRAG 120 0 1000".utf8))
    precondition(fields(field(1,[1,2,3]).dropLast().map{$0}).isEmpty)
    print("PASS: RPC varint boundaries, partial frames, nested application data, truncated fields")
    exit(0)
}
let gui = !CommandLine.arguments.contains("--cli") && (CommandLine.arguments.contains("--gui") || CommandLine.arguments[0].contains(".app/Contents/MacOS/"))
if gui {
    let app=NSApplication.shared
    let panel=ControlPanel(); app.delegate=panel; app.setActivationPolicy(.regular); app.run()
} else {
    let target=CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("--") }) ?? "Flipper"
    let bridge=MouseBridge(target:target)
    DispatchQueue.global().async {
        while let line=readLine() { DispatchQueue.main.async { bridge.submit(line) } }
        DispatchQueue.main.async { bridge.submit("STOP") }
    }
    RunLoop.main.run()
}
