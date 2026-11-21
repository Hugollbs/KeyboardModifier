import Foundation

// Noms des applications installées, calculés une seule fois au premier usage
let installedApps: [String] = {
    let folders = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        homeDirectory().appendingPathComponent("Applications").path,
    ]
    var names = Set<String>()
    for folder in folders {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        for file in files where file.hasSuffix(".app") {
            names.insert(String(file.dropLast(".app".count)))
        }
    }
    return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}()
