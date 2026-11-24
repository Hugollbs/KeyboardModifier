import Foundation
@testable import KeyboardModifier

// Faux IOKit : on déclenche les touches à la main
@MainActor
final class FakeHIDSource: HIDSource {
    var onKeyEvent: ((_ page: Int, _ usage: Int, _ value: Int) -> Void)?
    var onKeyboardConnected: (() -> Void)?
    var startError: Error?
    var otherKeyboards = true
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(keyboard: KeyboardID) throws {
        startCount += 1
        if let startError { throw startError }
    }

    func stop() { stopCount += 1 }

    func hasOtherKeyboards(than keyboard: KeyboardID) -> Bool { otherKeyboards }

    // Simule un événement du clavier (page 7 = touches, valeur 1 = appui)
    func send(usage: Int, page: Int = HID.keyboardPage, value: Int = 1) {
        onKeyEvent?(page, usage, value)
    }

    // Simule le retour du clavier (sortie de veille, rebranchement)
    func reconnect() {
        onKeyboardConnected?()
    }
}

// Faux hidutil : note ce qu'on lui demande
final class FakeMapping: KeyMappingController, @unchecked Sendable {
    var disableError: Error?
    var restoreError: Error?
    private(set) var disabled: [KeyboardID] = []
    private(set) var restored: [KeyboardID] = []

    func disableKeys(of keyboard: KeyboardID) throws {
        if let disableError { throw disableError }
        disabled.append(keyboard)
    }

    func restoreKeys(of keyboard: KeyboardID) throws {
        if let restoreError { throw restoreError }
        restored.append(keyboard)
    }
}

// Faux fichier d'état, en mémoire
final class FakeStore: DisabledKeyboardStore, @unchecked Sendable {
    var saved: [KeyboardID] = []
    func load() -> [KeyboardID] { saved }
    func add(_ keyboard: KeyboardID) { if !saved.contains(keyboard) { saved.append(keyboard) } }
    func remove(_ keyboard: KeyboardID) { saved.removeAll { $0 == keyboard } }
}
