import Foundation
import IOKit.hid

// Étape 1 : lister les claviers connectés et afficher les touches par appareil.
// On écoute seulement (pas de "seize") : aucune latence ajoutée, rien n'est bloqué.

func property(_ device: IOHIDDevice, _ key: String) -> Any? {
    IOHIDDeviceGetProperty(device, key as CFString)
}

func describe(_ device: IOHIDDevice) -> String {
    let name = property(device, kIOHIDProductKey) as? String ?? "Inconnu"
    let vendor = property(device, kIOHIDVendorIDKey) as? Int ?? 0
    let product = property(device, kIOHIDProductIDKey) as? Int ?? 0
    return "\(name) [vendor 0x\(String(vendor, radix: 16)), product 0x\(String(product, radix: 16))]"
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

// Usage page 0x01 (Generic Desktop), usage 0x06 (Keyboard)
let matching: [String: Int] = [
    kIOHIDDeviceUsagePageKey: 0x01,
    kIOHIDDeviceUsageKey: 0x06,
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, device in
    print("＋ Clavier connecté : \(describe(device))")
}, nil)

IOHIDManagerRegisterDeviceRemovalCallback(manager, { _, _, _, device in
    print("－ Clavier retiré : \(describe(device))")
}, nil)

IOHIDManagerRegisterInputValueCallback(manager, { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    // Usage page 0x07 = touches du clavier ; usages 4...231 = vraies touches
    guard IOHIDElementGetUsagePage(element) == 0x07 else { return }
    let usage = IOHIDElementGetUsage(element)
    guard (4...231).contains(usage) else { return }
    let pressed = IOHIDValueGetIntegerValue(value) != 0
    let device = IOHIDElementGetDevice(element)
    print("\(pressed ? "↓" : "↑") touche 0x\(String(usage, radix: 16)) — \(describe(device))")
}, nil)

IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
    print("Impossible d'ouvrir le gestionnaire HID. Autorise ton terminal dans Réglages Système > Confidentialité > Surveillance de l'entrée.")
    exit(1)
}

print("En écoute… (Ctrl+C pour quitter)")
setvbuf(stdout, nil, _IOLBF, 0)
CFRunLoopRun()
