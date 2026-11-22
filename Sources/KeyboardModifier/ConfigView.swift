import SwiftUI

// Une ligne de la fenêtre : une touche et son action
struct RuleRow: Identifiable {
    let id = UUID()
    var key: Int
    var type: String   // "app" ou "shell"
    var value: String
}

// Un clavier de la colonne de droite : branché maintenant, ou configuré mais débranché
struct KeyboardEntry: Identifiable {
    let id: KeyboardID
    let name: String
    let isConnected: Bool
}

@MainActor
final class ConfigModel: ObservableObject {
    @Published var entries: [KeyboardEntry]
    @Published var selected: KeyboardID?
    @Published private var rowsByKeyboard: [KeyboardID: [RuleRow]] = [:] // modifs non enregistrées comprises
    @Published private(set) var running: Set<KeyboardID> = []
    @Published var isCapturing = false
    @Published var lastAdded: UUID? // pour mettre le curseur dans la ligne qu'on vient d'ajouter
    @Published var errorMessage: String?   // échec d'activation d'un clavier
    @Published var warningMessage: String?  // touche définie plusieurs fois
    private let manager: KeyboardManager

    init(manager: KeyboardManager) {
        self.manager = manager
        let connected = connectedKeyboards()
        var found = connected.map { KeyboardEntry(id: $0.id, name: $0.name, isConnected: true) }
        for known in manager.keyboards where !connected.contains(where: { $0.id == known.id }) {
            found.append(KeyboardEntry(id: known.id, name: known.name, isConnected: false))
        }
        entries = found.sorted { $0.name < $1.name }
        for known in manager.keyboards {
            rowsByKeyboard[known.id] = known.rules.map { RuleRow(key: $0.key, type: $0.action.type, value: $0.action.value) }
        }
        refreshRunning()
        select(entries.first?.id)
    }

    var selectedEntry: KeyboardEntry? { entries.first { $0.id == selected } }
    var isSelectedRunning: Bool { selected.map(running.contains) ?? false }

    // Les lignes du clavier sélectionné
    var rows: [RuleRow] {
        get { selected.flatMap { rowsByKeyboard[$0] } ?? [] }
        set { if let selected { rowsByKeyboard[selected] = newValue } }
    }

    func select(_ id: KeyboardID?) {
        cancelCapture()
        selected = id
        errorMessage = nil
        let duplicates = id.map { findDuplicateKeys(in: rules(of: $0)) } ?? []
        warningMessage = duplicates.isEmpty ? nil
            : "Touche définie plusieurs fois : \(duplicates.map(keyName).joined(separator: ", ")). La dernière règle est utilisée."
    }

    // Appliqué tout de suite : le clavier est désactivé pour macOS, ou rendu
    func setEnabled(_ enabled: Bool) {
        guard let entry = selectedEntry else { return }
        manager.add(entry.id, name: entry.name) // sans effet si le clavier est déjà connu
        do {
            try manager.setEnabled(entry.id, enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshRunning() // l'interrupteur revient en arrière si l'activation a échoué
    }

    // Bouton « + » : on attend une touche du clavier sélectionné
    func startCapture() {
        guard let id = selected else { return }
        isCapturing = true
        manager.captureNextKey(on: id) { [weak self] key in
            guard let self else { return }
            self.isCapturing = false
            self.rows.removeAll { $0.key == key } // une touche = une seule action
            let row = RuleRow(key: key, type: "app", value: "")
            self.rows.append(row)
            self.lastAdded = row.id
        }
    }

    func cancelCapture() {
        manager.cancelCapture()
        isCapturing = false
    }

    func delete(_ id: UUID) {
        rows.removeAll { $0.id == id }
    }

    // Enregistre les raccourcis de tous les claviers modifiés ou déjà connus
    func save() {
        for entry in entries {
            let rules = self.rules(of: entry.id)
            let isKnown = manager.keyboards.contains { $0.id == entry.id }
            guard isKnown || !rules.isEmpty else { continue }
            manager.add(entry.id, name: entry.name)
            manager.update(entry.id, name: entry.name, rules: rules)
        }
    }

    // Une ligne sans action n'a pas de sens : on l'ignore
    private func rules(of id: KeyboardID) -> [Rule] {
        (rowsByKeyboard[id] ?? [])
            .filter { !$0.value.isEmpty }
            .map { Rule(key: $0.key, action: Action(type: $0.type, value: $0.value)) }
    }

    private func refreshRunning() {
        running = Set(entries.map(\.id).filter(manager.isRunning))
    }
}

struct ConfigView: View {
    @ObservedObject var model: ConfigModel

    var body: some View {
        HStack(spacing: 0) {
            detail
            Divider()
            sidebar
        }
        .frame(minWidth: 760, minHeight: 360)
    }

    // Au centre : le clavier sélectionné, son interrupteur et ses raccourcis
    @ViewBuilder
    private var detail: some View {
        if let entry = model.selectedEntry {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.name).font(.title2.bold())
                        if !entry.isConnected {
                            Text("Débranché").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("Activer", isOn: Binding(get: { model.isSelectedRunning },
                                                    set: { model.setEnabled($0) }))
                        .toggleStyle(.switch)
                        .disabled(!entry.isConnected && !model.isSelectedRunning)
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
                        .disabled(model.isCapturing || !model.isSelectedRunning)
                    if model.isCapturing {
                        Text("Appuie sur une touche de ce clavier…").foregroundStyle(.secondary)
                        Button("Annuler") { model.cancelCapture() }
                    } else if !model.isSelectedRunning {
                        Text("Active le clavier pour ajouter un raccourci.").foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity)
        } else {
            Text("Aucun clavier externe détecté.\nBranche-en un pour le configurer.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // À droite : tous les claviers, un clic pour sélectionner
    private var sidebar: some View {
        List(selection: Binding(get: { model.selected }, set: { model.select($0) })) {
            ForEach(model.entries) { entry in
                HStack {
                    Circle()
                        .fill(model.running.contains(entry.id) ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading) {
                        Text(entry.name)
                        Text(entry.isConnected ? (model.running.contains(entry.id) ? "Actif" : "Inactif") : "Débranché")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(entry.id)
            }
        }
        .frame(width: 220)
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
