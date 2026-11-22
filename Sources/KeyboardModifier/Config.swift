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

// Un clavier connu de l'appli, avec ses propres raccourcis
struct KeyboardConfig: Codable, Equatable {
    let id: KeyboardID
    var name: String
    var enabled: Bool  // faux : le clavier reste normal pour macOS
    var rules: [Rule]
}

struct Config: Codable, Equatable {
    var keyboards: [KeyboardConfig]

    private enum CodingKeys: String, CodingKey {
        case keyboards
        case keyboard, rules // ancien format (v1.x) : un seul clavier et ses règles
    }

    init(keyboards: [KeyboardConfig]) {
        self.keyboards = keyboards
    }

    // Lit le nouveau format, ou convertit l'ancien : le clavier choisi devient un clavier actif
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.keyboards) {
            keyboards = try container.decode([KeyboardConfig].self, forKey: .keyboards)
            return
        }
        let oldKeyboard = try container.decodeIfPresent(KeyboardID.self, forKey: .keyboard)
        let oldRules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        guard let oldKeyboard else {
            if !oldRules.isEmpty { log.warning("Ancienne config sans clavier : \(oldRules.count) règle(s) ignorée(s)") }
            keyboards = []
            return
        }
        // Le vrai nom sera mis à jour dès que le clavier est branché
        let name = "Clavier \(oldKeyboard.vendorID):\(oldKeyboard.productID)"
        keyboards = [KeyboardConfig(id: oldKeyboard, name: name, enabled: true, rules: oldRules)]
    }

    // On n'écrit que le nouveau format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyboards, forKey: .keyboards)
    }
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
        return Config(keyboards: [])
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