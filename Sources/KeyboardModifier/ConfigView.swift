import SwiftUI

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
