import SwiftUI

// Les pages du panneau. Les trois premières sont dans la barre du haut ; .apps est
// une page secondaire (choix d'une application) qui glisse par-dessus les règles.
enum Page: Hashable {
    case rules, keyboards, settings
    case apps(UUID)

    var order: Int {
        switch self {
        case .rules, .apps: return 0
        case .keyboards: return 1
        case .settings: return 2
        }
    }
}

struct PopoverView: View {
    @ObservedObject var model: ConfigModel
    let close: () -> Void

    @State private var page: Page = .rules
    @State private var forward = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                switch page {
                case .rules: RulesPage(model: model, close: close, openApps: { go(.apps($0)) })
                case .keyboards: KeyboardsPage(model: model)
                case .settings: SettingsPage(model: model)
                case .apps(let id): AppsPage(model: model, rowID: id, back: { go(.rules) })
                }
            }
            // La page entrante arrive du côté où l'on va, la sortante part de l'autre
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(width: 480, height: 400)
    }

    private var header: some View {
        HStack {
            if case .apps = page {
                Button { go(.rules) } label: { Label("Retour", systemImage: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
            } else {
                Picker("", selection: Binding(get: { page }, set: { go($0) })) {
                    Label("Règles", systemImage: "list.bullet").tag(Page.rules)
                    Label("Clavier", systemImage: "keyboard").tag(Page.keyboards)
                    Label("Réglages", systemImage: "gearshape").tag(Page.settings)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(10)
    }

    private func go(_ target: Page) {
        forward = target.order >= page.order
        if case .apps = target { forward = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page = target }
    }
}

struct RulesPage: View {
    @ObservedObject var model: ConfigModel
    let close: () -> Void
    let openApps: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.rows.isEmpty {
                Spacer()
                Text(model.keyboard == nil ? "Choisis d'abord un clavier dans l'onglet Clavier."
                                           : "Aucune règle. Clique sur Ajouter puis appuie sur une touche.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach($model.rows) { $row in
                        HStack {
                            Text(keyName(row.key)).frame(width: 70, alignment: .leading)
                            Picker("", selection: $row.type) {
                                Text("App").tag("app")
                                Text("Commande").tag("shell")
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            TextField(row.type == "app" ? "Nom de l'app" : "Commande", text: $row.value)
                            if row.type == "app" {
                                Button { openApps(row.id) } label: { Image(systemName: "list.bullet") }
                                    .buttonStyle(.borderless)
                                    .help("Choisir parmi les applications installées")
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
                    Text("Appuie sur une touche…").foregroundStyle(.secondary)
                    Button("Annuler") { model.cancelCapture() }
                }
                Spacer()
                Button("Enregistrer") {
                    model.save()
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
    }
}

struct KeyboardsPage: View {
    @ObservedObject var model: ConfigModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clavier à reprogrammer").font(.headline)
            Text("Ses touches sont désactivées pour macOS et ne servent qu'à lancer tes actions.")
                .font(.caption).foregroundStyle(.secondary)
            List {
                choice("Aucun", id: nil)
                ForEach(model.keyboards, id: \.id) { choice($0.name, id: $0.id) }
            }
        }
        .padding(10)
    }

    private func choice(_ name: String, id: KeyboardID?) -> some View {
        Button { model.selectKeyboard(id) } label: {
            HStack {
                Text(name)
                Spacer()
                if model.keyboard == id { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsPage: View {
    @ObservedObject var model: ConfigModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Lancer à l'ouverture de session",
                   isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            Text("Garde l'appli à un emplacement fixe (par exemple /Applications).")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            HStack {
                Spacer()
                Button("Quitter KeyboardModifier") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
    }
}

// Page secondaire : liste des applications installées avec recherche
struct AppsPage: View {
    @ObservedObject var model: ConfigModel
    let rowID: UUID
    let back: () -> Void
    @State private var search = ""

    private var filtered: [String] {
        search.isEmpty ? installedApps : installedApps.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 8) {
            TextField("Rechercher une application…", text: $search)
            List(filtered, id: \.self) { name in
                Button(name) {
                    model.setValue(name, for: rowID)
                    back()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }
}
