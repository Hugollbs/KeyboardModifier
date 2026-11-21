import Foundation
import IOKit.hid

// Écoute le clavier ciblé, désactive ses touches pour macOS et lance les actions
final class Engine {
    private var config: Config
    private var captureHandler: ((Int) -> Void)?
    private var actions: [Int: Action] = [:]
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    init(config: Config) {
        self.config = config
        // Dictionnaire touche -> action : recherche instantanée à chaque frappe
        for rule in config.rules { actions[rule.key] = rule.action }
    }

    func start() {
        // On ne voit que le clavier ciblé : le clavier du Mac n'est jamais touché
        let matching: [String: Int] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x06,
            kIOHIDVendorIDKey: config.keyboard.vendorID,
            kIOHIDProductIDKey: config.keyboard.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        // Le callback est une fonction C : elle ne peut pas capturer self,
        // on le lui transmet donc via le pointeur "context"
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            Unmanaged<Engine>.fromOpaque(context).takeUnretainedValue().handle(value)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            print("Ouverture impossible. Autorise l'appli dans Réglages Système > Confidentialité > Surveillance de l'entrée.")
            exit(1)
        }
        setKeysDisabled(true, for: config.keyboard)
    }

    func stop() {
        setKeysDisabled(false, for: config.keyboard)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    var rules: [Rule] { config.rules }
    var keyboard: KeyboardID { config.keyboard }

    // Remplace les règles à chaud, sans toucher à l'écoute du clavier
    func updateRules(_ rules: [Rule]) {
        config = Config(keyboard: config.keyboard, rules: rules)
        actions = [:]
        for rule in rules { actions[rule.key] = rule.action }
    }

    // La prochaine touche pressée est donnée au handler au lieu de lancer une action
    func captureNextKey(_ handler: @escaping (Int) -> Void) {
        captureHandler = handler
    }

    func cancelCapture() {
        captureHandler = nil
    }
    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == 0x07 else { return }
        let usage = Int(IOHIDElementGetUsage(element))
        guard (4...231).contains(usage) else { return }
        guard IOHIDValueGetIntegerValue(value) != 0 else { return } // appui seulement
        if let capture = captureHandler {
            captureHandler = nil
            capture(usage)
            return
        }
        if let action = actions[usage] { run(action) }
    }
}
