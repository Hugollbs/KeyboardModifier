import SwiftUI

// Une ligne de la fenêtre : une touche et son action
struct RuleRow: Identifiable {
    let id = UUID()
    var key: Int
    var type: String   // "app" ou "shell"
    var value: String
}

@MainActor
final class ConfigModel: ObservableObject {
    @Published var rows: [RuleRow]
    @Published var isCapturing = false
    @Published var lastAdded: UUID? // pour mettre le curseur dans la ligne qu'on vient d'ajouter
    @Published var keyboard: KeyboardID?
    @Published var errorMessage: String?   // échec du changement de clavier
    @Published var warningMessage: String?  // touche définie plusieurs fois
    let keyboards = connectedKeyboards()
    private let engine: Engine

    init(engine: Engine) {
        self.engine = engine
        keyboard = engine.keyboard
        let duplicates = engine.duplicateKeys
        if !duplicates.isEmpty {
            warningMessage = "Touche définie plusieurs fois : \(duplicates.map(keyName).joined(separator: ", ")). La dernière règle est utilisée."
        }
        rows = engine.rules.map { RuleRow(key: $0.key, type: $0.action.type, value: $0.action.value) }
    }

    // Appliqué tout de suite : l'ancien clavier est rendu à macOS, le nouveau est désactivé
    func selectKeyboard(_ id: KeyboardID?) {
        do {
            try engine.setKeyboard(id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        keyboard = engine.keyboard // l'ancien clavier si le changement a échoué
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
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red).font(.callout)
            }
            if let message = model.warningMessage {
                Text(message).foregroundStyle(.orange).font(.callout)
            }
            List {
                ForEach($model.rows) { $row in
                    RuleRowView(row: $row, autofocus: row.id == model.lastAdded) { model.delete(row.id) }
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

// Une ligne : touche, type d'action, puis le champ de saisie ou, une fois l'appli choisie, son nom et son icône
struct RuleRowView: View {
    @Binding var row: RuleRow
    let autofocus: Bool
    let onDelete: () -> Void
    @State private var isEditingApp = false

    // L'appli choisie, si le texte est le nom d'une appli installée et qu'on ne le modifie pas
    private var chosenAppPath: String? {
        guard row.type == "app", !isEditingApp else { return nil }
        return appPath(named: row.value)
    }

    var body: some View {
        HStack {
            Text(keyName(row.key))
                .frame(width: 100, alignment: .leading)
            Picker("", selection: $row.type) {
                Text("Application").tag("app")
                Text("Commande").tag("shell")
            }
            .labelsHidden()
            .frame(width: 140)
            if let path = chosenAppPath {
                Text(row.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditingApp = true } // clic : on change d'appli
                    .help("Cliquer pour changer d'application")
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 28, height: 28)
            } else if row.type == "app" {
                AppField(text: $row.value, placeholder: "Nom de l'app (ex : Safari)",
                         autofocus: autofocus || isEditingApp) { isEditingApp = false }
            } else {
                TextField("Commande (ex : say bonjour)", text: $row.value)
            }
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
    }
}
