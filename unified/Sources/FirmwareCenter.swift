import AppKit
import SwiftUI

@MainActor final class FirmwareCenter:ObservableObject {
    static let shared=FirmwareCenter()
    @Published var packages=[FirmwarePackage]()
    @Published var knownVersions=UserDefaults.standard.dictionary(forKey:"FirmwareLastSeen") as? [String:String] ?? [:]
    var hasUpdate:Bool {packages.contains{p in knownVersions[p.id].map{p.version.compare($0,options:.numeric) == .orderedDescending} ?? false}}
    func observed(_ version:String,flipper:Bool) {
        guard version.range(of:"^[0-9]+[.][0-9]+[.][0-9]+$",options:.regularExpression) != nil else{return}
        knownVersions[flipper ? "flipper":"cardputer"]=version;UserDefaults.standard.set(knownVersions,forKey:"FirmwareLastSeen")
    }
    @Published var checking=false
    @Published var installing=false
    @Published var progress=0.0
    @Published var status="Bundled packages available."
    @Published var source="Included with this app"
    @Published var lastCheck="Not checked online yet"
    @Published var automatic:Bool {didSet{UserDefaults.standard.set(automatic,forKey:"FirmwareAutoCheck")}}
    @Published var ports=[String]()
    @Published var selectedPort=""
    private var catalog:FirmwareCatalog?
    private var timer:Timer?
    private var sessionOwner:SessionOwner?
    private let catalogURL=URL(string:"https://raw.githubusercontent.com/cmong67/flipper-mouse-bridge/main/unified/firmware-manifest.json")!
    init() {
        automatic=UserDefaults.standard.object(forKey:"FirmwareAutoCheck") as? Bool ?? true
        if let url=Bundle.main.url(forResource:"manifest",withExtension:"json",subdirectory:"Firmware"),let data=try? Data(contentsOf:url),let c=try? JSONDecoder().decode(FirmwareCatalog.self,from:data),(try? c.validate()) != nil {catalog=c;packages=c.packages}
        refreshPorts()
        if automatic {Task{await check()}}
        timer=Timer.scheduledTimer(withTimeInterval:6*3600,repeats:true){[weak self] _ in Task{@MainActor in if let self,self.automatic {await self.check()}}}
    }
    deinit{timer?.invalidate()}
    func refreshPorts(){ports=DeviceInventory.firmwarePorts();if !ports.contains(selectedPort){selectedPort=ports.first ?? ""}}
    static func fetch(_ url:URL,maximum:Int)async throws->Data {
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:20)
        request.setValue("application/octet-stream",forHTTPHeaderField:"Accept")
        let (bytes,response)=try await URLSession.shared.bytes(for:request)
        guard let http=response as? HTTPURLResponse,http.statusCode==200,http.url?.scheme=="https",http.url?.host=="raw.githubusercontent.com" else {throw FirmwareError.message("Update server did not return a valid package.")}
        if response.expectedContentLength>Int64(maximum){throw FirmwareError.message("Update exceeds the size limit.")}
        var data=Data()
        for try await byte in bytes {data.append(byte);if data.count>maximum{throw FirmwareError.message("Update exceeds the size limit.")}}
        return data
    }
    func check()async {
        guard !checking,!installing else{return};checking=true;defer{checking=false}
        do {
            let data=try await Self.fetch(catalogURL,maximum:32768)
            let c=try JSONDecoder().decode(FirmwareCatalog.self,from:data);try c.validate()
            catalog=c;packages=c.packages.map{remote in
                if let included=packages.first(where:{$0.id==remote.id}),included.version.compare(remote.version,options:.numeric) == .orderedDescending {return included}
                return remote
            };source="Latest published HID Emu packages"
            lastCheck=Date().formatted(date:.abbreviated,time:.shortened);status="Update check complete. Connect a device to compare its installed version."
        } catch {status="Online check unavailable. Verified packages included with this app remain available.";lastCheck="Check failed · "+Date().formatted(date:.omitted,time:.shortened)}
    }
    func install(_ p:FirmwarePackage) {
        guard !installing,!checking,DeviceInventory.firmwarePorts(for:p.id).contains(selectedPort) else{return}
        do {sessionOwner=try SessionOwner()}catch{status="Another HID Emu session is using the device. Close it and retry.";return}
        installing=true;progress=0;status="Verifying package…"
        let port=selectedPort
        Task {
            do {
                let data:Data
                if let url=Bundle.main.url(forResource:p.file,withExtension:nil,subdirectory:"Firmware"),let bundled=try? Data(contentsOf:url),(try? p.verify(bundled)) != nil {data=bundled}
                else {data=try await Self.fetch(p.url,maximum:p.bytes)}
                try p.verify(data)
                let support=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
                let folder=support.appendingPathComponent("HID Emu/Updates/"+UUID().uuidString,isDirectory:true)
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                try data.write(to:folder.appendingPathComponent(p.file),options:.atomic)
                try JSONEncoder().encode(p).write(to:folder.appendingPathComponent("package.json"),options:.atomic)
                let result=try await Task.detached(priority:.userInitiated) {
                    try FirmwareInstaller.install(p,data:data,port:port,backup:folder,reconnectPorts:{DeviceInventory.firmwarePorts(for:"cardputer")}){fraction,message in Task{@MainActor in if self.installing {self.progress=fraction;self.status=message}}}
                }.value
                status=result;progress=1;observed(p.version,flipper:p.id=="flipper")
                try result.write(to:folder.appendingPathComponent("result.txt"),atomically:true,encoding:.utf8)
            } catch {status="Update stopped: "+error.localizedDescription}
            installing=false;sessionOwner=nil;refreshPorts()
        }
    }
}

struct FirmwareCenterView:View {
    @ObservedObject var center:FirmwareCenter
    @ObservedObject var dashboard:Dashboard
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                VStack(alignment:.leading,spacing:4) {Text("Device updates").font(.title2.bold());Text("HID Emu companion apps · Flipper Zero + Cardputer ADV").foregroundStyle(.secondary).font(.system(size:12))}
                Spacer();Button("Done"){dismiss()}.disabled(center.installing)
            }
            HStack {Toggle("Check automatically",isOn:$center.automatic);Spacer();Button(center.checking ? "Checking…":"Check Now"){Task{await center.check()}}.disabled(center.checking || center.installing)}.font(.system(size:12))
            Text("\(center.source) · \(center.lastCheck)").font(.system(size:11)).foregroundStyle(.secondary)
            ForEach(center.packages){p in
                DashboardPanel {
                    HStack(spacing:12) {
                        VStack(alignment:.leading,spacing:5) {
                            Text(p.name).font(.headline)
                            Text("Available \(p.version) · Installed \(installed(p))").font(.system(size:12)).foregroundStyle(.secondary)
                            Text(p.id=="cardputer" ? "Updates Launcher’s MouseBridge slot; preserves M5Launcher.":"Updates the HID Emu app; preserves Flipper system firmware.").font(.system(size:11)).foregroundStyle(.secondary)
                        }.frame(maxWidth:.infinity,alignment:.leading)
                        Button(installed(p)==p.version ? "Reinstall":"Update Device"){center.install(p)}
                            .disabled(center.installing || center.checking || dashboard.connected || dashboard.connecting || !portMatches(p))
                    }
                }
            }
            VStack(alignment:.leading,spacing:8) {
                HStack {Text("USB device").font(.system(size:12,weight:.medium));Spacer();Button("Refresh"){center.refreshPorts()}.disabled(center.installing)}
                Picker("USB device",selection:$center.selectedPort){if center.ports.isEmpty {Text("No supported USB device detected").tag("")};ForEach(center.ports,id:\.self){Text($0).tag($0)}}.labelsHidden().disabled(center.installing)
                if dashboard.connected || dashboard.connecting {
                    HStack {Text("Disconnect mouse control before updating.").font(.system(size:12));Spacer();Button("Disconnect"){dashboard.disconnect();center.refreshPorts()}}
                }
                Text("Cardputer: press Reset once without G0 to enter Launcher. Flipper: connect USB, close qFlipper and return to the main screen. Keep USB connected until finished.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            ProgressView(value:center.progress).opacity(center.installing || center.progress>0 ? 1:0.3)
            Text(center.status).font(.system(size:12)).fixedSize(horizontal:false,vertical:true).textSelection(.enabled).frame(minHeight:42,alignment:.topLeading)
            Text("Checks run on launch and every six hours while this app is open. Installation starts when you choose Update Device. Packages are checked by size and SHA-256 before transfer.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }.padding(20).frame(width:600).background(Palette.background).preferredColorScheme(.dark)
            .interactiveDismissDisabled(center.installing).onAppear{center.refreshPorts()}
    }
    private func installed(_ p:FirmwarePackage)->String {
        guard dashboard.connected,(p.id=="flipper")==dashboard.isFlipper else{return center.knownVersions[p.id].map{$0+" (last seen)"} ?? "connect to read"}
        return dashboard.deviceVersion
    }
    private func portMatches(_ p:FirmwarePackage)->Bool {DeviceInventory.firmwarePorts(for:p.id).contains(center.selectedPort)}
}
