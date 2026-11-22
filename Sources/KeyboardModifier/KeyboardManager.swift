import Foundation

// Gère tous les claviers configurés : un Engine par clavier, démarré seulement s'il est activé.
// C'est lui qui tient la config à jour et l'écrit sur disque.
@MainActor
final class KeyboardManager {
    private(set) var config: Config
    private var engines: [KeyboardID: Engine] = [:]
    private let mapping: KeyMappingController
    private let store: DisabledKeyboardStore
    private let makeEngine: @MainActor (KeyboardConfig) -> Engine
    private let persist: (Config) -> Void

    init(config: Config, mapping: KeyMappingController, store: DisabledKeyboardStore,
         makeEngine: @escaping @MainActor (KeyboardConfig) -> Engine, persist: @escaping (Config) -> Void) {
        self.config = config
        self.mapping = mapping
        self.store = store
        self.makeEngine = makeEngine
        self.persist = persist
        for keyboard in config.keyboards { engines[keyboard.id] = makeEngine(keyboard) }
    }

    // Version de production : vrais IOKit, vrai hidutil, vrais fichiers
    convenience init(config: Config) {
        self.init(config: config, mapping: HidutilMapping(), store: FileDisabledKeyboardStore(),
                  makeEngine: { Engine(keyboard: $0.id, rules: $0.rules) },
                  persist: { saveConfig($0) })
    }

    var keyboards: [KeyboardConfig] { config.keyboards }
    // Au moins un clavier est actuellement désactivé pour macOS
    var isActive: Bool { engines.values.contains { $0.isActive } }

    func isRunning(_ id: KeyboardID) -> Bool { engines[id]?.isActive ?? false }

    func duplicateKeys(of id: KeyboardID) -> [Int] { engines[id]?.duplicateKeys ?? [] }

    // Au lancement : si l'appli précédente a été tuée sans pouvoir rendre les claviers, on les rend maintenant
    func restoreLeftoverMappings() {
        for keyboard in store.load() {
            do {
                try mapping.restoreKeys(of: keyboard)
                store.remove(keyboard)
                log.notice("Clavier \(keyboard.vendorID)/\(keyboard.productID) restauré après un arrêt brutal")
            } catch {
                log.error("Restauration impossible : \(error.localizedDescription)")
            }
        }
    }

    // Démarre tous les claviers activés. Un échec n'empêche pas les autres de démarrer ;
    // la première erreur est renvoyée à la fin.
    func start() throws {
        var firstError: Error?
        for keyboard in config.keyboards where keyboard.enabled {
            do {
                try engines[keyboard.id]?.start()
            } catch {
                log.error("Démarrage de \(keyboard.name) impossible : \(error.localizedDescription)")
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }

    // Rend tous les claviers à macOS, sans toucher à ce qui est activé dans la config
    func stop() {
        for engine in engines.values { engine.stop() }
    }

    // Après une veille : on ré-applique seulement aux claviers actuellement pris en charge
    func restartRunning() {
        for engine in engines.values where engine.isActive {
            do {
                try engine.start()
            } catch {
                log.error("Redémarrage impossible : \(error.localizedDescription)")
            }
        }
    }

    // Active ou désactive un clavier tout de suite. Si l'activation échoue, la config ne change pas.
    func setEnabled(_ id: KeyboardID, _ enabled: Bool) throws {
        guard let index = config.keyboards.firstIndex(where: { $0.id == id }),
              let engine = engines[id] else { return }
        if enabled {
            try engine.start()
        } else {
            engine.stop()
        }
        config.keyboards[index].enabled = enabled
        persist(config)
    }

    // Ajoute un clavier jamais vu, désactivé au départ. Sans effet s'il est déjà connu.
    func add(_ id: KeyboardID, name: String) {
        guard !config.keyboards.contains(where: { $0.id == id }) else { return }
        let keyboard = KeyboardConfig(id: id, name: name, enabled: false, rules: [])
        config.keyboards.append(keyboard)
        engines[id] = makeEngine(keyboard)
        persist(config)
    }

    // Remplace les règles (et le nom) d'un clavier à chaud, sans toucher à l'écoute
    func update(_ id: KeyboardID, name: String, rules: [Rule]) {
        guard let index = config.keyboards.firstIndex(where: { $0.id == id }) else { return }
        config.keyboards[index].name = name
        config.keyboards[index].rules = rules
        engines[id]?.updateRules(rules)
        persist(config)
    }

    // La prochaine touche de ce clavier est donnée au handler (le clavier doit être pris en charge)
    func captureNextKey(on id: KeyboardID, _ handler: @escaping (Int) -> Void) {
        engines[id]?.captureNextKey(handler)
    }

    func cancelCapture() {
        for engine in engines.values { engine.cancelCapture() }
    }
}
