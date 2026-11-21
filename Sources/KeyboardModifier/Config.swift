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
    let keyboard: KeyboardID
    let rules: [Rule]
}

let configPath = ".config/keyboardmodifier/config.json"

func loadConfig() -> Config {
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(configPath)
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    } catch {
        print("Config illisible (\(url.path)) : \(error)")
        exit(1)
    }
}
