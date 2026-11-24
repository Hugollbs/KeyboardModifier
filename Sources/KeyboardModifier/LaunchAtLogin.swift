import Foundation

private let agentLabel = "com.hugollbs.keyboardmodifier"

private var agentURL: URL {
    homeDirectory().appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
}

func isLaunchAtLoginEnabled() -> Bool {
    FileManager.default.fileExists(atPath: agentURL.path)
}

// Seule l'appli signée par make-app.sh a une identité stable pour macOS. Un binaire nu (build Debug
// de VS Code) change d'identité à chaque compilation : macOS redemanderait les autorisations.
func isAppBundle(_ bundleURL: URL) -> Bool {
    bundleURL.pathExtension == "app"
}

var isRunningFromAppBundle: Bool { isAppBundle(Bundle.main.bundleURL) }

// L'exécutable que lance le LaunchAgent (nil si le fichier est absent ou illisible)
func launchAgentExecutable(at url: URL) -> String? {
    guard let plist = NSDictionary(contentsOf: url),
          let arguments = plist["ProgramArguments"] as? [String] else { return nil }
    return arguments.first
}

// Si le LaunchAgent lance un autre exécutable que l'appli courante (ex. ancien build Debug),
// on le fait pointer vers celle-ci. Seulement depuis un .app, pour ne jamais y remettre un binaire nu.
func repairLaunchAtLoginIfNeeded() {
    guard isRunningFromAppBundle, isLaunchAtLoginEnabled(),
          let current = Bundle.main.executablePath,
          launchAgentExecutable(at: agentURL) != current else { return }
    log.notice("LaunchAgent redirigé vers \(current)")
    setLaunchAtLogin(true)
}

// Un LaunchAgent lance l'appli à l'ouverture de session ; il ne démarre rien tout de suite
func setLaunchAtLogin(_ enabled: Bool) {
    guard enabled else {
        try? FileManager.default.removeItem(at: agentURL)
        return
    }
    guard isRunningFromAppBundle else {
        log.error("Lancement à l'ouverture de session refusé : l'appli ne tourne pas depuis un .app")
        return
    }
    guard let executable = Bundle.main.executablePath else {
        log.error("Chemin de l'exécutable introuvable")
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
        try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: agentURL, options: .atomic)
    } catch {
        log.error("Impossible d'écrire le LaunchAgent : \(error.localizedDescription)")
    }
}
