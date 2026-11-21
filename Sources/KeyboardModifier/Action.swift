import Foundation

func run(_ action: Action) {
    let process = Process()
    switch action.type {
    case "app":
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", action.value]
    case "shell":
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", action.value]
    default:
        print("Type d'action inconnu : \(action.type)")
        return
    }
    do {
        try process.run() // ne bloque pas : on n'attend pas la fin
    } catch {
        print("Échec de l'action : \(error)")
    }
}
