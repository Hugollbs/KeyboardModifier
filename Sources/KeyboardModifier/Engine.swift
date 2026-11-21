import Foundation

// Écoute le clavier ciblé, désactive ses touches pour macOS et lance les actions
@MainActor
final class Engine {
    private var config: Config
    private var actions: [Int: Action] = [:]
    private var captureHandler: ((Int) -> Void)?
    private let source: HIDSource
    private let mapping: KeyMappingController
    private let store: DisabledKeyboardStore
    private let runAction: @MainActor (Action) -> Void
    // Non nil quand on a désactivé les touches de ce clavier : c'est ce qu'il faudra restaurer
    private var disabledKeyboard: KeyboardID?

    init(config: Config, source: HIDSource, mapping: KeyMappingController,
         store: DisabledKeyboardStore, runAction: @escaping @MainActor (Action) -> Void) {
        self.config = config
        self.source = source
        self.mapping = mapping
        self.store = store
        self.runAction = runAction
        buildActions()
    }

    // Version de production : vrais IOKit, vrai hidutil, vrai fichier d'état
    convenience init(config: Config) {
        self.init(config: config, source: IOKitHIDSource(), mapping: HidutilMapping(),
                  store: FileDisabledKeyboardStore(), runAction: run)
    }

    // Dernier filet de sécurité : si l'Engine disparaît, le clavier est rendu à macOS
    deinit {
        MainActor.assumeIsolated { stop() }
    }

    var rules: [Rule] { config.rules }
    var keyboard: KeyboardID? { config.keyboard }
    var isActive: Bool { disabledKeyboard != nil }
    var duplicateKeys: [Int] { findDuplicateKeys(in: config.rules) }

    // Au lancement : si l'appli précédente a été tuée sans pouvoir rendre le clavier, on le rend maintenant
    func restoreLeftoverMapping() {
        guard let keyboard = store.load() else { return }
        do {
            try mapping.restoreKeys(of: keyboard)
            store.save(nil)
            log.notice("Clavier \(keyboard.vendorID)/\(keyboard.productID) restauré après un arrêt brutal")
        } catch {
            log.error("Restauration impossible : \(error.localizedDescription)")
        }
    }

    func start() throws {
        stop() // pas d'écrasement : on repart toujours d'un état propre
        // Aucun clavier choisi : rien à écouter, rien à désactiver
        guard let keyboard = config.keyboard else { return }
        guard keyboard.isValid else { throw EngineError.invalidKeyboard }
        guard source.hasOtherKeyboards(than: keyboard) else { throw EngineError.onlyKeyboard }

        source.onKeyEvent = { [weak self] page, usage, value in
            self?.handle(page: page, usage: usage, value: value)
        }
        try source.start(keyboard: keyboard)

        // On note le clavier AVANT de le désactiver : si l'appli est tuée entre les deux,
        // le prochain lancement saura quoi restaurer
        store.save(keyboard)
        do {
            try mapping.disableKeys(of: keyboard)
        } catch {
            source.stop()
            source.onKeyEvent = nil
            try? mapping.restoreKeys(of: keyboard) // hidutil a pu appliquer le mapping à moitié
            store.save(nil)
            throw error
        }
        disabledKeyboard = keyboard
    }

    func stop() {
        source.stop()
        source.onKeyEvent = nil
        guard let keyboard = disabledKeyboard else { return } // on ne restaure que ce qu'on a désactivé
        do {
            try mapping.restoreKeys(of: keyboard)
            store.save(nil)
        } catch {
            // L'état reste sur disque : le prochain lancement réessaiera
            log.error("Impossible de rendre le clavier à macOS : \(error.localizedDescription)")
        }
        disabledKeyboard = nil
    }

    // Change de clavier ciblé. Si le nouveau ne peut pas s'ouvrir, la config garde l'ancien.
    func setKeyboard(_ keyboard: KeyboardID?) throws {
        let previous = config
        stop()
        config = Config(keyboard: keyboard, rules: config.rules)
        do {
            try start()
        } catch {
            config = previous
            try? start() // on remet l'ancien clavier en service
            throw error
        }
    }

    // Remplace les règles à chaud, sans toucher à l'écoute du clavier
    func updateRules(_ rules: [Rule]) {
        config = Config(keyboard: config.keyboard, rules: rules)
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
        let duplicates = findDuplicateKeys(in: config.rules)
        if !duplicates.isEmpty {
            // La dernière règle l'emporte, mais on le dit au lieu de le faire en silence
            log.warning("Touches définies plusieurs fois (la dernière règle est utilisée) : \(duplicates)")
        }
        actions = [:]
        for rule in config.rules { actions[rule.key] = rule.action }
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
