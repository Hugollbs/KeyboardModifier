import Foundation
import IOKit.hid

struct ConnectedKeyboard: Hashable {
    let id: KeyboardID
    let name: String
}

// Claviers actuellement branchés, hors clavier intégré du Mac
func connectedKeyboards() -> [ConnectedKeyboard] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [String: Int] = [kIOHIDDeviceUsagePageKey: HID.genericDesktopPage, kIOHIDDeviceUsageKey: HID.keyboardUsage]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }

    var found = Set<ConnectedKeyboard>()
    for device in devices {
        if IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? Bool == true { continue }
        guard let vendor = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
              let product = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int else { continue }
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Clavier inconnu"
        found.insert(ConnectedKeyboard(id: KeyboardID(vendorID: vendor, productID: product), name: name))
    }
    return found.sorted { $0.name < $1.name }
}
