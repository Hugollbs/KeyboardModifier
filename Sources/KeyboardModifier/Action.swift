import Foundation

// Si l'appli a été lancée depuis VS Code, elle hérite de ses variables. `open` les transmet à
// l'appli ouverte : avec ELECTRON_RUN_AS_NODE=1, VS Code démarre comme un simple Node et quitte aussitôt.
func cleanedEnvironment(_ environment: [String: String]) -> [String: String] {
    environment.filter { key, _ in key != "ELECTRON_RUN_AS_NODE" && !key.hasPrefix("VSCODE_") }
}

func run(_ action: Action) {
    let command: [String]
    switch action.type {
    case "app":
        command = ["/usr/bin/open", "-a", action.value]
    case "shell":
        command = ["/bin/zsh", "-c", action.value]
    default:
        log.error("Type d'action inconnu : \(action.type)")
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: command[0])
    process.arguments = Array(command.dropFirst())
    process.environment = cleanedEnvironment(ProcessInfo.processInfo.environment)
    do {
        try process.run() // ne bloque pas : on n'attend pas la fin
    } catch {
        log.error("Échec de l'action : \(error.localizedDescription)")
    }
}
