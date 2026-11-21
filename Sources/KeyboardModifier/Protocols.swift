// Les trois dépendances d'Engine qui touchent au système, derrière des protocoles
// pour pouvoir les remplacer par des faux dans les tests.

// Reçoit les événements du clavier ciblé (en vrai : IOHIDManager)
@MainActor
protocol HIDSource: AnyObject {
    // page, usage et valeur de chaque événement HID
    var onKeyEvent: ((_ page: Int, _ usage: Int, _ value: Int) -> Void)? { get set }
    func start(keyboard: KeyboardID) throws
    func stop()
    // Y a-t-il un autre clavier que celui-ci (le clavier du Mac compte) ?
    func hasOtherKeyboards(than keyboard: KeyboardID) -> Bool
}

// Désactive / réactive les touches d'un clavier pour macOS (en vrai : hidutil)
protocol KeyMappingController {
    func disableKeys(of keyboard: KeyboardID) throws
    func restoreKeys(of keyboard: KeyboardID) throws
}

// Mémorise sur disque le clavier dont on a désactivé les touches,
// pour le réactiver au prochain lancement si l'appli est tuée (kill -9)
protocol DisabledKeyboardStore {
    func load() -> KeyboardID?
    func save(_ keyboard: KeyboardID?)
}
