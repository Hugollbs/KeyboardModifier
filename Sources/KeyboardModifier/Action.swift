import Foundation

func run(_ action: Action) {
    var command: [String]
    switch action.type {
    case "app":
        command = ["/usr/bin/open", "-a", action.value]
    case "shell":
        command = ["/bin/zsh", "-c", action.value]
    default:
        print("Type d'action inconnu : \(action.type)")
        return
    }
    // Sous sudo, on lance l'action avec les droits de l'utilisateur, jamais en root
    if let user = sudoUser {
        command = ["/usr/bin/sudo", "-u", user] + command
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: command[0])
    process.arguments = Array(command.dropFirst())
    do {
        try process.run() // ne bloque pas : on n'attend pas la fin
    } catch {
        print("Échec de l'action : \(error)")
    }
}
