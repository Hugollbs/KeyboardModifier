import Foundation
import IOKit.hid

let config = loadConfig()

// Dictionnaire touche -> action : recherche instantanée à chaque frappe
var actions: [Int: Action] = [:]
for rule in config.rules { actions[rule.key] = rule.action }

func name(of device: IOHIDDevice) -> String {
    IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Inconnu"
}

// Appelée à chaque changement d'état d'une touche du clavier ciblé
func onKey(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ value: IOHIDValue) {
    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetUsagePage(element) == 0x07 else { return }
    let usage = Int(IOHIDElementGetUsage(element))
    guard (4...231).contains(usage) else { return }
    guard IOHIDValueGetIntegerValue(value) != 0 else { return } // appui seulement
    print("touche \(usage) (0x\(String(usage, radix: 16)))")
    if let action = actions[usage] { run(action) }
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

// On ne voit que le clavier ciblé : le clavier du Mac n'est jamais touché
let matching: [String: Int] = [
    kIOHIDDeviceUsagePageKey: 0x01,
    kIOHIDDeviceUsageKey: 0x06,
    kIOHIDVendorIDKey: config.keyboard.vendorID,
    kIOHIDProductIDKey: config.keyboard.productID,
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, device in
    print("Clavier détecté : \(name(of: device))")
}, nil)
IOHIDManagerRegisterInputValueCallback(manager, onKey, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

// Lecture simple, sans capture exclusive
let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard result == kIOReturnSuccess else {
    print("Ouverture impossible. Autorise ton terminal dans Réglages Système > Confidentialité > Surveillance de l'entrée.")
    exit(1)
}

// Les touches du clavier ciblé n'écrivent plus rien dans macOS
setKeysDisabled(true, for: config.keyboard)

// À l'arrêt (Ctrl+C ou kill), on rend le clavier à macOS
func restoreAndQuit() {
    setKeysDisabled(false, for: config.keyboard)
    exit(0)
}
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigint.setEventHandler(handler: restoreAndQuit)
sigterm.setEventHandler(handler: restoreAndQuit)
sigint.resume()
sigterm.resume()

print("En écoute… Arrête avec Ctrl+C sur le clavier du Mac.")
setvbuf(stdout, nil, _IOLBF, 0)
CFRunLoopRun()
