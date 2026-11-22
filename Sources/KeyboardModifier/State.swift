import Foundation

// Stockage des claviers « désactivés » dans ~/.config/keyboardmodifier/state.json
struct FileDisabledKeyboardStore: DisabledKeyboardStore {
    let url: URL

    init(url: URL = homeDirectory().appendingPathComponent(".config/keyboardmodifier/state.json")) {
        self.url = url
    }

    func load() -> [KeyboardID] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let keyboards = try? JSONDecoder().decode([KeyboardID].self, from: data) { return keyboards }
        // Fichier écrit par une version à un seul clavier
        if let keyboard = try? JSONDecoder().decode(KeyboardID.self, from: data) { return [keyboard] }
        return []
    }

    func add(_ keyboard: KeyboardID) {
        let keyboards = load()
        if !keyboards.contains(keyboard) { write(keyboards + [keyboard]) }
    }

    func remove(_ keyboard: KeyboardID) {
        write(load().filter { $0 != keyboard })
    }

    private func write(_ keyboards: [KeyboardID]) {
        guard !keyboards.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try writePrivateFile(try JSONEncoder().encode(keyboards), to: url)
        } catch {
            log.error("Impossible d'écrire l'état (\(url.path)) : \(error.localizedDescription)")
        }
    }
}
