import Foundation
import IOKit
import IOKit.serial

enum DeviceInventory {
    static func cardputerPorts()->[String] {
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
            if product.localizedCaseInsensitiveContains("Cardputer") || (!serial.isEmpty && enrolled.contains(serial)) {ports.append(path)}
        }
        return ports.sorted()
    }
}
