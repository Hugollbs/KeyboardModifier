import Foundation

struct KeyboardID: Codable, Hashable {
    let vendorID: Int
    let productID: Int

    // Les identifiants USB tiennent sur 16 bits
    var isValid: Bool {
        (0...0xFFFF).contains(vendorID) && (0...0xFFFF).contains(productID)
    }
}

struct Action: Codable, Equatable {
    let type: String   // "app" ou "shell"
    let value: String  // nom de l'app ou commande
}

struct Rule: Codable, Equatable {
    let key: Int       // code HID de la touche (4 = A)
    let action: Action
}

struct Config: Codable, Equatable {
    let keyboard: KeyboardID? // nil tant qu'aucun clavier n'est choisi
    let rules: [Rule]
}

// Touches qui apparaissent dans plusieurs règles (sans doublon dans le résultat, triées)
func findDuplicateKeys(in rules: [Rule]) -> [Int] {
    var seen = Set<Int>()
    var duplicates = Set<Int>()
    for rule in rules where !seen.insert(rule.key).inserted {
        duplicates.insert(rule.key)
    }
    return duplicates.sorted()
}

func homeDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
}

let configPath = ".config/keyboardmodifier/config.json"

struct ConfigError: Error, LocalizedError {
    let path: String
    let reason: String
    var errorDescription: String? { "Le fichier de configuration est illisible (\(path)) : \(reason)" }
}

func loadConfig(at url: URL = homeDirectory().appendingPathComponent(configPath)) throws -> Config {
    // Premier lancement : pas de fichier, on démarre avec une config vide
    guard FileManager.default.fileExists(atPath: url.path) else {
        return Config(keyboard: nil, rules: [])
    }
    do {
        // Un fichier créé par une ancienne version peut être lisible par d'autres : on le resserre
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    } catch {
        log.error("Config illisible (\(url.path)) : \(error.localizedDescription)")
        throw ConfigError(path: url.path, reason: error.localizedDescription)
    }
}

// config.json contient des commandes exécutées par zsh : seul l'utilisateur doit pouvoir le lire
// et le modifier (dossier en 700, fichier en 600)
func writePrivateFile(_ data: Data, to url: URL) throws {
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
    try data.write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}

func saveConfig(_ config: Config, to url: URL = homeDirectory().appendingPathComponent(configPath)) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        try writePrivateFile(try encoder.encode(config), to: url)
    } catch {
        log.error("Impossible d'écrire la config (\(url.path)) : \(error.localizedDescription)")
    }
}