import Foundation
import IOKit.hid

// Écoute le clavier ciblé, désactive ses touches pour macOS et lance les actions
final class Engine {
    private var config: Config
    private var captureHandler: ((Int) -> Void)?
    private var actions: [Int: Action] = [:]
    private var manager: IOHIDManager?

    init(config: Config) {
        self.config = config
        // Dictionnaire touche -> action : recherche instantanée à chaque frappe
        for rule in config.rules { actions[rule.key] = rule.action }
    }

    func start() {
        // Aucun clavier choisi : rien à écouter, rien à désactiver
        guard let keyboard = config.keyboard else { return }
        // On ne voit que le clavier ciblé : le clavier du Mac n'est jamais touché
        let matching: [String: Int] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x06,
            kIOHIDVendorIDKey: keyboard.vendorID,
            kIOHIDProductIDKey: keyboard.productID,
        ]
        // Un manager neuf à chaque start() : on peut changer de clavier à chaud
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
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
        setKeysDisabled(true, for: keyboard)
    }

    func stop() {
        if let keyboard = config.keyboard { setKeysDisabled(false, for: keyboard) }
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
    }
    var rules: [Rule] { config.rules }
    var keyboard: KeyboardID? { config.keyboard }

    // Change de clavier ciblé : on rend l'ancien à macOS, puis on écoute le nouveau
    func setKeyboard(_ keyboard: KeyboardID?) {
        stop()
        config = Config(keyboard: keyboard, rules: config.rules)
        start()
    }

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
