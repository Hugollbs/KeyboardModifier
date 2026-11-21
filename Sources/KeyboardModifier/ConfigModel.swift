import Foundation

// Une ligne de la fenêtre : une touche et son action
struct RuleRow: Identifiable {
    let id = UUID()
    var key: Int
    var type: String   // "app" ou "shell"
    var value: String
}

final class ConfigModel: ObservableObject {
    @Published var rows: [RuleRow]
    @Published var isCapturing = false
    @Published var keyboard: KeyboardID?
    @Published var launchAtLogin = isLaunchAtLoginEnabled()
    let keyboards = connectedKeyboards()
    private let engine: Engine

    init(engine: Engine) {
        self.engine = engine
        keyboard = engine.keyboard
        rows = engine.rules.map { RuleRow(key: $0.key, type: $0.action.type, value: $0.action.value) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        KeyboardModifier.setLaunchAtLogin(enabled)
        launchAtLogin = isLaunchAtLoginEnabled()
    }

    // Appliqué tout de suite : l'ancien clavier est rendu à macOS, le nouveau est désactivé
    func selectKeyboard(_ id: KeyboardID?) {
        engine.setKeyboard(id)
        keyboard = id
    }

    // Bouton « + » : on attend une touche du clavier externe
    func startCapture() {
        isCapturing = true
        engine.captureNextKey { [weak self] key in
            guard let self else { return }
            self.isCapturing = false
            self.rows.removeAll { $0.key == key } // une touche = une seule action
            self.rows.append(RuleRow(key: key, type: "app", value: ""))
        }
    }

    func cancelCapture() {
        engine.cancelCapture()
        isCapturing = false
    }

    func delete(_ id: UUID) {
        rows.removeAll { $0.id == id }
    }

    func save() {
        // Une ligne sans action n'a pas de sens : on l'ignore
        let rules = rows
            .filter { !$0.value.isEmpty }
            .map { Rule(key: $0.key, action: Action(type: $0.type, value: $0.value)) }
        engine.updateRules(rules)
        saveConfig(Config(keyboard: engine.keyboard, rules: rules))
    }
}
