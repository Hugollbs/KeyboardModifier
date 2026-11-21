import SwiftUI

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
    @Published var lastAdded: UUID? // pour mettre le curseur dans la ligne qu'on vient d'ajouter
    @Published var keyboard: KeyboardID?
    let keyboards = connectedKeyboards()
    private let engine: Engine

    init(engine: Engine) {
        self.engine = engine
        keyboard = engine.keyboard
        rows = engine.rules.map { RuleRow(key: $0.key, type: $0.action.type, value: $0.action.value) }
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
            let row = RuleRow(key: key, type: "app", value: "")
            self.rows.append(row)
            self.lastAdded = row.id
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

struct ConfigView: View {
    @ObservedObject var model: ConfigModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Clavier", selection: Binding(get: { model.keyboard }, set: { model.selectKeyboard($0) })) {
                Text("Aucun").tag(KeyboardID?.none)
                ForEach(model.keyboards, id: \.id) { keyboard in
                    Text(keyboard.name).tag(KeyboardID?.some(keyboard.id))
                }
            }
            List {
                ForEach($model.rows) { $row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(keyName(row.key))
                                .frame(width: 100, alignment: .leading)
                            Picker("", selection: $row.type) {
                                Text("Application").tag("app")
                                Text("Commande").tag("shell")
                            }
                            .labelsHidden()
                            .frame(width: 140)
                            if row.type == "app" {
                                AppField(text: $row.value, placeholder: "Nom de l'app (ex : Safari)",
                                         autofocus: row.id == model.lastAdded)
                            } else {
                                TextField("Commande (ex : say bonjour)", text: $row.value)
                            }
                            Button { model.delete(row.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }
            HStack {
                Button { model.startCapture() } label: { Label("Ajouter", systemImage: "plus") }
                    .disabled(model.isCapturing || model.keyboard == nil)
                if model.isCapturing {
                    Text("Appuie sur une touche du clavier externe…")
                        .foregroundStyle(.secondary)
                    Button("Annuler") { model.cancelCapture() }
                }
                Spacer()
                Button("Enregistrer") {
                    model.save()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 320)
    }
}
