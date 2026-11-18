import Foundation
import CryptoKit
import Darwin

struct FirmwarePackage:Codable,Identifiable {
    let id:String;let name:String;let version:String;let bytes:Int;let sha256:String;let file:String;let url:URL
    let target:Int?;let apiMajor:Int?;let apiMinor:Int?
    func validate() throws {
        guard ["cardputer","flipper"].contains(id),bytes>0,bytes<=4_194_304,
              sha256.count==64,sha256.allSatisfy({$0.isHexDigit}),
              file == (id=="cardputer" ? "cardputer.bin":"flipper.fap"),
              !version.isEmpty,version.count<32,
              url.scheme=="https",url.host=="raw.githubusercontent.com",
              url.path.hasPrefix("/cmong67/flipper-mouse-bridge/main/releases/"),
              !url.path.contains(".."),url.query==nil,url.fragment==nil,
              id != "flipper" || (target==7 && apiMajor != nil && apiMinor != nil)
        else {throw FirmwareError.message("Unsupported update package.")}
    }
    func verify(_ data:Data)throws {
        try validate()
        guard data.count==bytes,Self.hash(data)==sha256.lowercased() else {throw FirmwareError.message("Package checksum or size did not match. Nothing was installed.")}
    }
    static func hash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
}
struct FirmwareCatalog:Codable {
    let schema:Int;let packages:[FirmwarePackage]
    func validate()throws {
        guard schema==1,packages.count==2,Set(packages.map(\.id))==Set(["cardputer","flipper"]) else {throw FirmwareError.message("Unsupported update catalog.")}
        try packages.forEach{try $0.validate()}
    }
}
enum FirmwareError:Error,LocalizedError {
    case message(String)
    var errorDescription:String? {if case let .message(s)=self{return s};return nil}
}

protocol FirmwareChannel {
    func write(_ data:Data)throws
    func send(_ text:String)throws
    func until(_ marker:Data,timeout:Double)throws->Data
    func line(timeout:Double)throws->String
    func cli(_ command:String)throws->String
    func readFile(_ path:String)throws->Data
}
extension FirmwareChannel {
    func line()throws->String {try line(timeout:15)}
    func until(_ marker:Data)throws->Data {try until(marker,timeout:10)}
}
// A bounded, exclusive USB transaction. Used only after the mouse session is closed.
final class FirmwareSerial:FirmwareChannel {
    private var fd:Int32 = -1
    private var buffer=Data()
    init(_ path:String)throws {
        guard path.hasPrefix("/dev/cu.usbmodem"),path.split(separator:"/").count==2 else {throw FirmwareError.message("Select a USB device port.")}
        fd=Darwin.open(path,O_RDWR|O_NOCTTY|O_NONBLOCK)
        guard fd>=0 else {throw FirmwareError.message("USB port unavailable. Close qFlipper and other serial apps.")}
        do {
            guard ioctl(fd,TIOCEXCL)==0 else {throw FirmwareError.message("USB port is in use.")}
            var t=termios();guard tcgetattr(fd,&t)==0 else {throw FirmwareError.message("Cannot configure USB.")}
            cfmakeraw(&t);cfsetispeed(&t,speed_t(B115200));cfsetospeed(&t,speed_t(B115200));t.c_cflag |= tcflag_t(CLOCAL|CREAD)
            guard tcsetattr(fd,TCSANOW,&t)==0 else {throw FirmwareError.message("Cannot configure USB.")}
            tcflush(fd,TCIFLUSH)
            // Launcher hardware CDC waits for the host to assert its terminal lines.
            var control:Int32=TIOCM_DTR|TIOCM_RTS
            _ = ioctl(fd,TIOCMBIC,&control)
            usleep(50_000)
            _ = ioctl(fd,TIOCMBIS,&control)
        } catch {close();throw error}
    }
    func close(){if fd>=0 {_ = ioctl(fd,TIOCNXCL);Darwin.close(fd);fd = -1}}
    deinit{close()}
    func write(_ data:Data)throws {
        var sent=0;let deadline=ProcessInfo.processInfo.systemUptime+15
        while sent<data.count {
            let n=data.withUnsafeBytes{Darwin.write(fd,$0.baseAddress!.advanced(by:sent),data.count-sent)}
            if n>0 {sent+=n}
            else if n<0 && errno != EAGAIN && errno != EINTR {throw FirmwareError.message("USB disconnected during transfer. Return to Launcher or reconnect Flipper and retry.")}
            if ProcessInfo.processInfo.systemUptime>deadline {throw FirmwareError.message("USB write timed out.")}
            if n<=0 {usleep(10_000)}
        }
    }
    func send(_ text:String)throws {try write(Data(text.utf8))}
    func until(_ marker:Data,timeout:Double=10)throws->Data {
        let end=ProcessInfo.processInfo.systemUptime+timeout
        while ProcessInfo.processInfo.systemUptime<end {
            if let range=buffer.range(of:marker) {let out=buffer.prefix(upTo:range.lowerBound);buffer.removeSubrange(..<range.upperBound);return Data(out)}
            try receive();usleep(5_000)
        }
        throw FirmwareError.message("Device reply timed out. Keep USB connected and return the Cardputer to Launcher before retrying.")
    }
    func receive()throws {
        var bytes=[UInt8](repeating:0,count:4096);let n=Darwin.read(fd,&bytes,bytes.count)
        if n>0 {buffer.append(contentsOf:bytes.prefix(n));if buffer.count>4_500_000 {throw FirmwareError.message("Oversized device reply.")}}
        else if n<0 && errno != EAGAIN && errno != EINTR {throw FirmwareError.message("USB connection was lost.")}
    }
    func exact(_ size:Int)throws->Data {
        let end=ProcessInfo.processInfo.systemUptime+15
        while buffer.count<size {try receive();if ProcessInfo.processInfo.systemUptime>end {throw FirmwareError.message("Readback timed out.")};usleep(5_000)}
        let data=Data(buffer.prefix(size));buffer.removeFirst(size);return data
    }
    func line(timeout:Double=15)throws->String {String(decoding:try until(Data([10]),timeout:timeout),as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)}
    func cli(_ command:String)throws->String {
        try send(command+"\r")
        var reply=""
        for _ in 0..<4 {
            reply=String(decoding:try until(Data(">: ".utf8)),as:UTF8.self)
            if !reply.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {break}
        }
        guard !reply.contains("Storage error:"),!reply.contains("Unknown command"),!reply.contains("Usage:") else {throw FirmwareError.message("Flipper rejected the storage command: "+String(reply.suffix(180)))}
        return reply
    }
    func readFile(_ path:String)throws->Data {
        try send("storage read_chunks \"\(path)\" 1024\r")
        var size:Int?
        for _ in 0..<6 {
            let text=try line()
            if text.hasPrefix("Size: "){size=Int(text.dropFirst(6));break}
            if text.contains("Storage error:"){throw FirmwareError.message("Cannot back up the installed Flipper app.")}
        }
        guard let size,size>0,size<=4_194_304 else {throw FirmwareError.message("Invalid Flipper file size.")}
        var result=Data()
        while result.count<size {
            _ = try until(Data("Ready?\r\n".utf8));try send("y");result.append(try exact(min(1024,size-result.count)))
        }
        _ = try until(Data(">: ".utf8));return result
    }
}

enum FirmwareInstaller {
    typealias Progress=(Double,String)->Void
    static func install(_ package:FirmwarePackage,data:Data,port:String,backup:URL,reconnectPorts:()->[String]={[]},progress:Progress)throws->String {
        try package.verify(data)
        let serial=try FirmwareSerial(port);defer{serial.close()}
        // CDC endpoints need a brief settling interval after DTR is asserted.
        usleep(250_000)
        if package.id=="cardputer" {
            _ = try cardputer(package,data,serial,progress);serial.close()
            progress(0.98,"Waiting for Cardputer to reboot and report its version…")
            for _ in 0..<25 {
                usleep(400_000)
                do {
                    let check=try FirmwareSerial(reconnectPorts().first ?? port);defer{check.close()}
                    try check.send("info\n")
                    for _ in 0..<4 {
                        let line=try check.line(timeout:1)
                        if line=="OK BRIDGE=\(package.version)" {
                            try check.send("stop\n")
                            for _ in 0..<4 {if try check.line(timeout:1)=="OK STOP" {progress(1,"Cardputer version verified and mouse control stopped.");return "Cardputer HID Emu \(package.version) installed, version verified and disarmed."}}
                            throw FirmwareError.message("Version verified, but STOP was not acknowledged.")
                        }
                    }
                } catch {continue}
            }
            throw FirmwareError.message("Launcher accepted the app, but its running version could not be confirmed. Reconnect in the dashboard to check firmware \(package.version).")
        }
        return try flipper(package,data,serial,backup,progress)
    }
    static func cardputer(_ p:FirmwarePackage,_ data:Data,_ s:FirmwareChannel,_ progress:Progress)throws->String {
        progress(0.05,"Checking M5Launcher…")
        var compatible=false
        for _ in 0..<3 {
            try s.send("help\n")
            let end=ProcessInfo.processInfo.systemUptime+2
            do {
                while ProcessInfo.processInfo.systemUptime<end {
                    let line=try s.line(timeout:2)
                    if line.contains("flash overwrite <name> <size>"){compatible=true;break}
                    if line.contains("ERR"){break}
                }
            } catch {if !error.localizedDescription.hasPrefix("Device reply timed out."){throw error}}
            if compatible {break}
            usleep(250_000)
        }
        guard compatible else {throw FirmwareError.message("Press Reset once without G0 to return to M5Launcher, then retry. Nothing was flashed.")}
        progress(0.06,"Configuring Launcher home menu…");try s.send("settings set {\"bootToApp\":false,\"DDLB\":false}\n")
        var settings=false
        for _ in 0..<60 {let text=try s.line();if text.hasPrefix("OK settings loaded"){settings=true;break};if text.hasPrefix("ERR"){throw FirmwareError.message(text)}}
        guard settings else {throw FirmwareError.message("Launcher settings were not acknowledged.")}
        progress(0.07,"Preparing the existing app slot…");try s.send("flash overwrite MouseBridge \(data.count)\n")
        var ready=false
        for _ in 0..<60 {let text=try s.line();if text=="READY \(data.count)"{ready=true;break};if text.hasPrefix("ERR"){throw FirmwareError.message(text)}}
        guard ready else {throw FirmwareError.message("Launcher did not accept the app image.")}
        var sent=0,acked=0
        let deadline=ProcessInfo.processInfo.systemUptime+180
        while acked<data.count {
            guard ProcessInfo.processInfo.systemUptime<deadline else {throw FirmwareError.message("Cardputer transfer timed out.")}
            while sent<data.count && sent-acked<4096 {
                let size=min(2048,data.count-sent);try s.write(data.subdata(in:sent..<sent+size));sent+=size
            }
            let text=try s.line()
            if text.hasPrefix("ERR"){throw FirmwareError.message(text)}
            guard text.hasPrefix("ACK ") else {continue}
            let counts=text.dropFirst(4).split(separator:"/")
            guard counts.count==2,let n=Int(counts[0]),Int(counts[1])==data.count,n>=acked,n<=sent else {throw FirmwareError.message("Invalid Launcher progress acknowledgement.")}
            acked=n;progress(0.1+0.85*Double(acked)/Double(data.count),"Installing Cardputer · \(acked*100/data.count)%")
        }
        do {
            for _ in 0..<60 {
                let text=try s.line(timeout:5)
                if text.hasPrefix("ERR"){throw FirmwareError.message(text)}
                if text=="OK flashed, rebooting" {return "Launcher accepted the app and is rebooting."}
            }
        } catch {
            // Some USB CDC drivers drop the final line during reset. All bytes
            // were acknowledged above; success still requires a running-version
            // check and STOP acknowledgement in install(), after re-enumeration.
            let message=error.localizedDescription
            guard message=="USB connection was lost." || message.hasPrefix("Device reply timed out.") else {throw error}
        }
        return "All bytes acknowledged; waiting for running-version verification."
    }
    static func flipper(_ p:FirmwarePackage,_ data:Data,_ s:FirmwareChannel,_ backup:URL,_ progress:Progress)throws->String {
        try s.send("\r");_ = try s.until(Data(">: ".utf8))
        let info=try s.cli("device_info")
        func value(_ key:String)->String? {info.components(separatedBy:"\n").first{$0.trimmingCharacters(in:.whitespaces).hasPrefix(key+" ")}.flatMap{$0.split(separator:":",maxSplits:1).last.map{String($0).trimmingCharacters(in:.whitespacesAndNewlines)}}}
        guard value("hardware_model")=="Flipper Zero",value("hardware_target")==String(p.target!),
              value("firmware_api_major")==String(p.apiMajor!),let minor=value("firmware_api_minor").flatMap(Int.init),minor>=p.apiMinor!
        else {throw FirmwareError.message("This companion requires Flipper target \(p.target!), API \(p.apiMajor!).\(p.apiMinor!) or a compatible minor version. System firmware was not changed.")}
        let destination="/ext/apps/Tools/ble_usb_mouse.fap"
        let stage="/ext/apps/Tools/hid_emu_update_"+UUID().uuidString+".tmp"
        progress(0.08,"Backing up the installed Flipper app…")
        let original=try s.readFile(destination);try original.write(to:backup.appendingPathComponent("flipper-before.fap"),options:.atomic)
        var sent=0
        while sent<data.count {
            let size=min(1024,data.count-sent)
            try s.send("storage write_chunk \"\(stage)\" \(size)\r")
            var ready=false
            for _ in 0..<5 {let line=try s.line();if line=="Ready"{ready=true;break};if line.contains("Storage error:"){throw FirmwareError.message(line)}}
            guard ready else {throw FirmwareError.message("Flipper was not ready for file transfer.")}
            try s.write(data.subdata(in:sent..<sent+size));let response=String(decoding:try s.until(Data(">: ".utf8)),as:UTF8.self)
            guard !response.contains("Storage error:") else {throw FirmwareError.message(response)}
            sent+=size;progress(0.12+0.6*Double(sent)/Double(data.count),"Sending Flipper app · \(sent*100/data.count)%")
        }
        progress(0.78,"Verifying full file readback…")
        guard try s.readFile(stage)==data else {throw FirmwareError.message("Flipper readback failed. The installed app is unchanged.")}
        // Keep a device-side recovery copy before replacing the destination.
        let deviceBackup="/ext/apps/Tools/hid_emu_previous_"+UUID().uuidString+".bak"
        _ = try s.cli("storage rename \"\(destination)\" \"\(deviceBackup)\"")
        do {
            _ = try s.cli("storage rename \"\(stage)\" \"\(destination)\"")
            guard try s.readFile(destination)==data else {throw FirmwareError.message("Installed readback mismatch. Backup: \(deviceBackup)")}
        } catch {
            // Restore only when destination is absent; never remove an uncertain file.
            _ = try? s.cli("storage rename \"\(deviceBackup)\" \"\(destination)\"")
            throw error
        }
        progress(1,"Flipper app installed and full readback verified.")
        return "Flipper HID Emu \(p.version) installed. Reconnect from the dashboard. Previous app saved on the Mac and Flipper."
    }
}
