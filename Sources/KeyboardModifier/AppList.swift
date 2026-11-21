import Foundation

private let appFolders = [
    "/Applications",
    "/Applications/Utilities",
    "/System/Applications",
    "/System/Applications/Utilities",
    homeDirectory().appendingPathComponent("Applications").path,
]

// Applis système utiles qui ne sont pas dans les dossiers ci-dessus
private let systemApps = ["Finder": "/System/Library/CoreServices/Finder.app"]

// Chemin de l'appli de ce nom (sans « .app »), nil si elle n'est dans aucun dossier connu
func appPath(named name: String) -> String? {
    if let path = systemApps[name] { return path }
    return appFolders
        .map { "\($0)/\(name).app" }
        .first { FileManager.default.fileExists(atPath: $0) }
}

// Noms des applications installées, calculés une seule fois au premier usage
let installedApps: [String] = {
    var names = Set(systemApps.keys)
    for folder in appFolders {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        for file in files where file.hasSuffix(".app") {
            names.insert(String(file.dropLast(".app".count)))
        }
    }
    return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}()
