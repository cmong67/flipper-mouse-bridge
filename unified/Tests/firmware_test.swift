import Foundation

final class FakeChannel:FirmwareChannel {
    var lines=[String]();var commands=[String]();var files=[Data]();var badReadback=false
    var exhausted="mock timeout"
    var info="hardware_model : Flipper Zero\nhardware_target : 7\nfirmware_api_major : 87\nfirmware_api_minor : 1\n"
    func write(_ data:Data)throws{}
    func send(_ text:String)throws{commands.append(text)}
    func until(_ marker:Data,timeout:Double)throws->Data{Data()}
    func line(timeout:Double)throws->String{guard !lines.isEmpty else {throw FirmwareError.message(exhausted)};return lines.removeFirst()}
    func cli(_ command:String)throws->String{commands.append(command);return command=="device_info" ? info:""}
    func readFile(_ path:String)throws->Data{commands.append("read "+path);guard !files.isEmpty else {throw FirmwareError.message("mock missing file")};return files.removeFirst()}
}
@main struct FirmwareTests {
    static func main()throws {
        let data=Data([1,2,3,4]);let hash=FirmwarePackage.hash(data)
        func package(_ id:String="cardputer",_ url:String="https://raw.githubusercontent.com/cmong67/flipper-mouse-bridge/main/releases/test.bin")->FirmwarePackage {FirmwarePackage(id:id,name:id,version:"1.0.0",bytes:4,sha256:hash,file:id=="cardputer" ? "cardputer.bin":"flipper.fap",url:URL(string:url)!,target:id=="flipper" ? 7:nil,apiMajor:id=="flipper" ? 87:nil,apiMinor:id=="flipper" ? 1:nil)}
        func rejects(_ action:()throws->Void){do{try action();fatalError("invalid operation accepted")}catch{}}
        try package().verify(data)
        rejects{try package().verify(Data([4,3,2,1]))}
        rejects{try package("cardputer","https://evil.example/file").validate()}
        rejects{try FirmwareCatalog(schema:1,packages:[package(),package()]).validate()}
        let card=FakeChannel();card.lines=["flash overwrite <name> <size>","OK settings loaded","READY 4","ACK 4/4","OK flashed, rebooting"]
        _ = try FirmwareInstaller.cardputer(package(),data,card){_,_ in}
        precondition(card.commands.contains("flash overwrite MouseBridge 4\n"))
        let reboot=FakeChannel();reboot.lines=["flash overwrite <name> <size>","OK settings loaded","READY 4","ACK 4/4"];reboot.exhausted="USB connection was lost."
        let pending=try FirmwareInstaller.cardputer(package(),data,reboot){_,_ in};precondition(pending.contains("running-version"))
        let wrong=FakeChannel();wrong.lines=["ERR unknown command"]
        rejects{_ = try FirmwareInstaller.cardputer(package(),data,wrong){_,_ in}}
        precondition(!wrong.commands.contains(where:{$0.hasPrefix("flash ")}))
        let ack=FakeChannel();ack.lines=["flash overwrite <name> <size>","OK settings loaded","READY 4","ACK 8/4"]
        rejects{_ = try FirmwareInstaller.cardputer(package(),data,ack){_,_ in}}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let flipper=FakeChannel();flipper.lines=["Ready"];flipper.files=[Data([9]),data,data]
        _ = try FirmwareInstaller.flipper(package("flipper"),data,flipper,folder){_,_ in}
        let saved=try Data(contentsOf:folder.appendingPathComponent("flipper-before.fap"));precondition(saved==Data([9]))
        precondition(flipper.commands.filter{$0.hasPrefix("storage rename")}.count==2)
        let corrupt=FakeChannel();corrupt.lines=["Ready"];corrupt.files=[Data([9]),Data([0])]
        rejects{_ = try FirmwareInstaller.flipper(package("flipper"),data,corrupt,folder){_,_ in}}
        precondition(!corrupt.commands.contains(where:{$0.hasPrefix("storage rename")}))
        let api=FakeChannel();api.info="hardware_model : Flipper Zero\nhardware_target : 7\nfirmware_api_major : 86\nfirmware_api_minor : 1\n"
        rejects{_ = try FirmwareInstaller.flipper(package("flipper"),data,api,folder){_,_ in}}
        precondition(!api.commands.contains(where:{$0.hasPrefix("read ")}))
        print("PASS: catalog origin and checksum guards, Launcher preflight and ACK bounds, Flipper API gate, backup, staged readback and replacement")
    }
}
