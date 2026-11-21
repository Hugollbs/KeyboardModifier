import Foundation

func run(_ action: Action) {
    let command: [String]
    switch action.type {
    case "app":
        command = ["/usr/bin/open", "-a", action.value]
    case "shell":
        command = ["/bin/zsh", "-c", action.value]
    default:
        print("Type d'action inconnu : \(action.type)")
        return
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
