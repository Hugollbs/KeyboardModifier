import Foundation
import IOKit.hid

let config = loadConfig()

// Dictionnaire touche -> action : recherche instantanée à chaque frappe
var actions: [Int: Action] = [:]
for rule in config.rules { actions[rule.key] = rule.action }

func name(of device: IOHIDDevice) -> String {
    IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Inconnu"
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

IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, device in
    print("Clavier capturé : \(name(of: device))")
}, nil)

IOHIDManagerRegisterInputValueCallback(manager, { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetUsagePage(element) == 0x07 else { return }
    let usage = Int(IOHIDElementGetUsage(element))
    guard (4...231).contains(usage) else { return }
    guard IOHIDValueGetIntegerValue(value) != 0 else { return } // appui seulement
    print("touche \(usage) (0x\(String(usage, radix: 16)))")
    if let action = actions[usage] { run(action) }
}, nil)

IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

// Seize = capture exclusive : macOS ne reçoit plus les touches de ce clavier
let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
guard result == kIOReturnSuccess else {
    print("Ouverture impossible (code 0x\(String(UInt32(bitPattern: result), radix: 16))). Essaie avec sudo ou vérifie la Surveillance de l'entrée.")
    exit(1)
}

print("En écoute… (Ctrl+C pour quitter)")
setvbuf(stdout, nil, _IOLBF, 0)
CFRunLoopRun()
