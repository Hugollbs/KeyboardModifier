import Foundation

// Écoute UN clavier, désactive ses touches pour macOS et lance les actions.
// KeyboardManager en crée un par clavier configuré.
@MainActor
final class Engine {
    let keyboard: KeyboardID
    private(set) var rules: [Rule]
    private var actions: [Int: Action] = [:]
    private var captureHandler: ((Int) -> Void)?
    private let source: HIDSource
    private let mapping: KeyMappingController
    private let store: DisabledKeyboardStore
    private let runAction: @MainActor (Action) -> Void
    // Vrai quand on a désactivé les touches de ce clavier : c'est ce qu'il faudra restaurer
    private(set) var isActive = false

    init(keyboard: KeyboardID, rules: [Rule], source: HIDSource, mapping: KeyMappingController,
         store: DisabledKeyboardStore, runAction: @escaping @MainActor (Action) -> Void) {
        self.keyboard = keyboard
        self.rules = rules
        self.source = source
        self.mapping = mapping
        self.store = store
        self.runAction = runAction
        buildActions()
    }

    // Version de production : vrais IOKit, vrai hidutil, vrai fichier d'état
    convenience init(keyboard: KeyboardID, rules: [Rule]) {
        self.init(keyboard: keyboard, rules: rules, source: IOKitHIDSource(), mapping: HidutilMapping(),
                  store: FileDisabledKeyboardStore(), runAction: run)
    }

    // Dernier filet de sécurité : si l'Engine disparaît, le clavier est rendu à macOS
    deinit {
        MainActor.assumeIsolated { stop() }
    }

    var duplicateKeys: [Int] { findDuplicateKeys(in: rules) }

    func start() throws {
        stop() // pas d'écrasement : on repart toujours d'un état propre
        guard keyboard.isValid else { throw EngineError.invalidKeyboard }
        guard source.hasOtherKeyboards(than: keyboard) else { throw EngineError.onlyKeyboard }

        source.onKeyEvent = { [weak self] page, usage, value in
            self?.handle(page: page, usage: usage, value: value)
        }
        try source.start(keyboard: keyboard)

        // On note le clavier AVANT de le désactiver : si l'appli est tuée entre les deux,
        // le prochain lancement saura quoi restaurer
        store.add(keyboard)
        do {
            try mapping.disableKeys(of: keyboard)
        } catch {
            source.stop()
            source.onKeyEvent = nil
            try? mapping.restoreKeys(of: keyboard) // hidutil a pu appliquer le mapping à moitié
            store.remove(keyboard)
            throw error
        }
        isActive = true
    }

    func stop() {
        source.stop()
        source.onKeyEvent = nil
        guard isActive else { return } // on ne restaure que ce qu'on a désactivé
        do {
            try mapping.restoreKeys(of: keyboard)
            store.remove(keyboard)
        } catch {
            // L'état reste sur disque : le prochain lancement réessaiera
            log.error("Impossible de rendre le clavier à macOS : \(error.localizedDescription)")
        }
        isActive = false
    }

    // Remplace les règles à chaud, sans toucher à l'écoute du clavier
    func updateRules(_ rules: [Rule]) {
        self.rules = rules
        buildActions()
    }

    // La prochaine touche pressée est donnée au handler au lieu de lancer une action
    func captureNextKey(_ handler: @escaping (Int) -> Void) {
        captureHandler = handler
    }

    func cancelCapture() {
        captureHandler = nil
    }

    // Dictionnaire touche -> action : recherche instantanée à chaque frappe
    private func buildActions() {
        let duplicates = findDuplicateKeys(in: rules)
        if !duplicates.isEmpty {
            // La dernière règle l'emporte, mais on le dit au lieu de le faire en silence
            log.warning("Touches définies plusieurs fois (la dernière règle est utilisée) : \(duplicates)")
        }
        actions = [:]
        for rule in rules { actions[rule.key] = rule.action }
    }

    private func handle(page: Int, usage: Int, value: Int) {
        guard let key = pressedKey(page: page, usage: usage, value: value) else { return }
        if let capture = captureHandler {
            captureHandler = nil
            capture(key)
            return
        }
        if let action = actions[key] { runAction(action) }
    }
}
