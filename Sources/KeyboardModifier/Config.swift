import Foundation

struct KeyboardID: Codable {
    let vendorID: Int
    let productID: Int
}

struct Action: Codable {
    let type: String   // "app" ou "shell"
    let value: String  // nom de l'app ou commande
}

struct Rule: Codable {
    let key: Int       // code HID de la touche (4 = A)
    let action: Action
}

struct Config: Codable {
    let keyboard: KeyboardID? // nil tant qu'aucun clavier n'est choisi
    let rules: [Rule]
}

let sudoUser: String? = getuid() == 0 ? ProcessInfo.processInfo.environment["SUDO_USER"] : nil

func homeDirectory() -> URL {
    if let user = sudoUser, let path = NSHomeDirectoryForUser(user) {
        return URL(fileURLWithPath: path)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}

let configPath = ".config/keyboardmodifier/config.json"

func loadConfig() -> Config {
    let url = homeDirectory().appendingPathComponent(configPath)
    // Premier lancement : pas de fichier, on démarre avec une config vide
    guard FileManager.default.fileExists(atPath: url.path) else {
        return Config(keyboard: nil, rules: [])
    }
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    } catch {
        print("Config illisible (\(url.path)) : \(error)")
        exit(1)
    }
}

func saveConfig(_ config: Config) {
    let url = homeDirectory().appendingPathComponent(configPath)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        try encoder.encode(config).write(to: url, options: .atomic)
    } catch {
        print("Impossible d'écrire la config (\(url.path)) : \(error)")
    }
}