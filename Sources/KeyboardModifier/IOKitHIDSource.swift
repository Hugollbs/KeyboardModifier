import Foundation
@preconcurrency import IOKit.hid

// Vraie source de touches : un IOHIDManager qui ne voit que le clavier ciblé
@MainActor
final class IOKitHIDSource: HIDSource {
    var onKeyEvent: ((_ page: Int, _ usage: Int, _ value: Int) -> Void)?
    var onKeyboardConnected: (() -> Void)?
    // L'appareil IOKit apparaît un peu avant le service que vise hidutil : sans ce délai,
    // hidutil ne trouverait encore rien (et répondrait quand même « succès »)
    private static let connectionDelay: TimeInterval = 1
    // nonisolated(unsafe) : deinit n'est pas isolé au thread principal mais doit pouvoir lire le manager ;
    // c'est sûr car au moment du deinit plus personne d'autre n'a de référence sur cet objet
    nonisolated(unsafe) private var manager: IOHIDManager?

    func start(keyboard: KeyboardID) throws {
        stop() // jamais deux managers en même temps
        // On ne voit que le clavier ciblé : le clavier du Mac n'est jamais touché
        let matching: [String: Int] = [
            kIOHIDDeviceUsagePageKey: HID.genericDesktopPage,
            kIOHIDDeviceUsageKey: HID.keyboardUsage,
            kIOHIDVendorIDKey: keyboard.vendorID,
            kIOHIDProductIDKey: keyboard.productID,
        ]
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        // Le callback est une fonction C : elle ne peut pas capturer self,
        // on le lui transmet donc via le pointeur "context"
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            let element = IOHIDValueGetElement(value)
            let page = Int(IOHIDElementGetUsagePage(element))
            let usage = Int(IOHIDElementGetUsage(element))
            let pressed = IOHIDValueGetIntegerValue(value)
            // Le manager est planifié sur le run loop principal : on est donc sur le thread principal
            MainActor.assumeIsolated {
                Unmanaged<IOKitHIDSource>.fromOpaque(context).takeUnretainedValue().onKeyEvent?(page, usage, pressed)
            }
        }, context)
        // Appelé par IOKit chaque fois que le clavier ciblé est détecté : à l'ouverture s'il est
        // déjà branché, puis à chaque fois que macOS le recrée (sortie de veille, rebranchement)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<IOKitHIDSource>.fromOpaque(context).takeUnretainedValue().keyboardDidAppear()
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            Self.teardown(manager, wasOpened: false)
            if result == kIOReturnNotPermitted || result == kIOReturnNotPrivileged {
                throw EngineError.permissionDenied
            }
            throw EngineError.openFailed(code: result)
        }
        self.manager = manager
    }

    // weak : si la source a été détruite entre-temps, on ne fait rien
    private func keyboardDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectionDelay) { [weak self] in
            MainActor.assumeIsolated { self?.onKeyboardConnected?() }
        }
    }

    func stop() {
        guard let manager else { return }
        Self.teardown(manager, wasOpened: true)
        self.manager = nil
    }

    // Si l'objet disparaît sans stop(), le callback ne doit plus pointer vers lui
    deinit {
        if let manager { Self.teardown(manager, wasOpened: true) }
    }

    // Débranche le callback (plus aucun appel vers self), retire le manager du run loop et le ferme
    private nonisolated static func teardown(_ manager: IOHIDManager, wasOpened: Bool) {
        IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        if wasOpened { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
    }

    func hasOtherKeyboards(than keyboard: KeyboardID) -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Int] = [kIOHIDDeviceUsagePageKey: HID.genericDesktopPage,
                                       kIOHIDDeviceUsageKey: HID.keyboardUsage]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return false }
        return devices.contains { device in
            let vendor = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int
            let product = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
            return vendor != keyboard.vendorID || product != keyboard.productID
        }
    }
}
