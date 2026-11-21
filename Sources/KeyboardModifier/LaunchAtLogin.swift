import Foundation

private let agentLabel = "com.hugollbs.keyboardmodifier"

private var agentURL: URL {
    homeDirectory().appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
}

func isLaunchAtLoginEnabled() -> Bool {
    FileManager.default.fileExists(atPath: agentURL.path)
}

// Un LaunchAgent lance l'appli à l'ouverture de session ; il ne démarre rien tout de suite
func setLaunchAtLogin(_ enabled: Bool) {
    guard enabled else {
        try? FileManager.default.removeItem(at: agentURL)
        return
    }
    guard let executable = Bundle.main.executablePath else {
        print("Chemin de l'exécutable introuvable")
        return
    }
    let plist: [String: Any] = [
        "Label": agentLabel,
        "ProgramArguments": [executable],
        "RunAtLoad": true,
        // Relancée après un plantage (pour re-désactiver le clavier), pas après « Quitter »
        "KeepAlive": ["SuccessfulExit": false],
    ]
    do {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)
    } catch {
        print("Impossible d'écrire le LaunchAgent : \(error)")
    }
}
