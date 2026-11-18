import Foundation
import IOKit
import IOKit.serial

enum DeviceInventory {
    static func cardputerPorts()->[String] { firmwarePorts(for:"cardputer") }
    static func firmwarePorts(for kind:String?=nil)->[String] {
        var iterator:io_iterator_t=0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching(kIOSerialBSDServiceValue),&iterator)==KERN_SUCCESS else{return []}
        defer{IOObjectRelease(iterator)}
        var ports=[String]()
        while true {
            let service=IOIteratorNext(iterator);if service==0 {break}
            defer{IOObjectRelease(service)}
            guard let path=IORegistryEntryCreateCFProperty(service,kIOCalloutDeviceKey as CFString,kCFAllocatorDefault,0)?.takeRetainedValue() as? String else{continue}
            let options=IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents)
            let product=IORegistryEntrySearchCFProperty(service,kIOServicePlane,"USB Product Name" as CFString,kCFAllocatorDefault,options) as? String ?? ""
            let serial=IORegistryEntrySearchCFProperty(service,kIOServicePlane,"USB Serial Number" as CFString,kCFAllocatorDefault,options) as? String ?? ""
            let enrolled=UserDefaults.standard.stringArray(forKey:"CardputerSerials") ?? []
            func normalized(_ value:String)->String {value.filter{$0.isLetter || $0.isNumber}.uppercased()}
            let vendor=IORegistryEntrySearchCFProperty(service,kIOServicePlane,"USB Vendor Name" as CFString,kCFAllocatorDefault,options) as? String ?? ""
            let cardputer=product.localizedCaseInsensitiveContains("Cardputer") || (!serial.isEmpty && enrolled.contains(where:{normalized($0)==normalized(serial)}))
            let flipper=product.localizedCaseInsensitiveContains("Flipper") || vendor.localizedCaseInsensitiveContains("Flipper Devices")
            if (kind==nil && (cardputer || flipper)) || (kind=="cardputer" && cardputer) || (kind=="flipper" && flipper) {ports.append(path)}
        }
        return ports.sorted()
    }
}
