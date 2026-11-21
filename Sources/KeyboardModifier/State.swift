import Foundation

// Stockage de l'état « clavier désactivé » dans ~/.config/keyboardmodifier/state.json
struct FileDisabledKeyboardStore: DisabledKeyboardStore {
    let url: URL

    init(url: URL = homeDirectory().appendingPathComponent(".config/keyboardmodifier/state.json")) {
        self.url = url
    }

    func load() -> KeyboardID? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(KeyboardID.self, from: data)
    }

    func save(_ keyboard: KeyboardID?) {
        guard let keyboard else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try writePrivateFile(try JSONEncoder().encode(keyboard), to: url)
        } catch {
            log.error("Impossible d'écrire l'état (\(url.path)) : \(error.localizedDescription)")
        }
    }
}
