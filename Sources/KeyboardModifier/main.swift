import Foundation
import IOKit.hid

let config = loadConfig()

// Dictionnaire touche -> action : recherche instantanée à chaque frappe
var actions: [Int: Action] = [:]
for rule in config.rules { actions[rule.key] = rule.action }

func name(of device: IOHIDDevice) -> String {
    IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Inconnu"
}

func hex(_ code: IOReturn) -> String {
    "0x" + String(UInt32(bitPattern: code), radix: 16)
}

// Appelée à chaque changement d'état d'une touche du clavier capturé
func onKey(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ value: IOHIDValue) {
    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetUsagePage(element) == 0x07 else { return }
    let usage = Int(IOHIDElementGetUsage(element))
    guard (4...231).contains(usage) else { return }
    guard IOHIDValueGetIntegerValue(value) != 0 else { return } // appui seulement
    print("touche \(usage) (0x\(String(usage, radix: 16)))")
    if let action = actions[usage] { run(action) }
}

// Appelée quand le clavier ciblé est détecté : on le capture lui seul
func onDevice(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ device: IOHIDDevice) {
    let status = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
    guard status == kIOReturnSuccess else {
        print("Capture de \(name(of: device)) impossible (code \(hex(status)))")
        return
    }
    print("Clavier capturé en exclusivité : \(name(of: device))")
    IOHIDDeviceRegisterInputValueCallback(device, onKey, nil)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

// On ne voit que le clavier ciblé : le clavier du Mac n'est jamais capturé
let matching: [String: Int] = [
    kIOHIDDeviceUsagePageKey: 0x01,
    kIOHIDDeviceUsageKey: 0x06,
    kIOHIDVendorIDKey: config.keyboard.vendorID,
    kIOHIDProductIDKey: config.keyboard.productID,
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
IOHIDManagerRegisterDeviceMatchingCallback(manager, onDevice, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

// Le gestionnaire ne sert qu'à détecter le clavier ; la capture se fait dans onDevice
let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard result == kIOReturnSuccess else {
    print("Ouverture impossible (code \(hex(result))). Lance avec sudo.")
    exit(1)
}

print("En écoute… (Ctrl+C pour quitter)")
setvbuf(stdout, nil, _IOLBF, 0)
CFRunLoopRun()
