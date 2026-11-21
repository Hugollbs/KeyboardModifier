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
    private let engine: Engine

    init(engine: Engine) {
        self.engine = engine
        rows = engine.rules.map { RuleRow(key: $0.key, type: $0.action.type, value: $0.action.value) }
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

struct ConfigView: View {
    @ObservedObject var model: ConfigModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach($model.rows) { $row in
                    HStack {
                        Text(keyName(row.key))
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $row.type) {
                            Text("Application").tag("app")
                            Text("Commande").tag("shell")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        TextField(row.type == "app" ? "Nom de l'app (ex : Safari)" : "Commande (ex : say bonjour)",
                                  text: $row.value)
                        if row.type == "app" {
                            AppPicker(selection: $row.value)
                        }
                        Button { model.delete(row.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            HStack {
                Button { model.startCapture() } label: { Label("Ajouter", systemImage: "plus") }
                    .disabled(model.isCapturing)
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
// Bouton qui ouvre la liste des applications installées, avec une recherche
struct AppPicker: View {
    @Binding var selection: String
    @State private var isOpen = false
    @State private var search = ""

    private var filtered: [String] {
        search.isEmpty ? installedApps : installedApps.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Button { isOpen = true } label: { Image(systemName: "list.bullet") }
            .help("Choisir parmi les applications installées")
            .popover(isPresented: $isOpen) {
                VStack {
                    TextField("Rechercher…", text: $search)
                    List(filtered, id: \.self) { name in
                        Button(name) {
                            selection = name
                            isOpen = false
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .frame(width: 260, height: 320)
            }
    }
}
