import Foundation

// Ce qui peut échouer quand on prend le contrôle d'un clavier
enum EngineError: Error, LocalizedError, Equatable {
    case permissionDenied          // macOS refuse la lecture du clavier (Surveillance de l'entrée)
    case openFailed(code: Int32)   // IOKit n'a pas pu ouvrir le clavier pour une autre raison
    case mappingFailed(String)     // hidutil a échoué (message d'erreur inclus)
    case invalidKeyboard           // vendorID / productID hors limites
    case onlyKeyboard              // désactiver ce clavier laisserait le Mac sans clavier

    // Un problème d'accès peut se régler en relançant l'appli après l'autorisation
    var isAccessProblem: Bool {
        switch self {
        case .permissionDenied, .openFailed: return true
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "macOS refuse l'accès au clavier. Autorise KeyboardModifier dans Réglages Système > Confidentialité et sécurité > Surveillance de l'entrée."
        case .openFailed(let code):
            return "Impossible d'ouvrir le clavier (code \(String(UInt32(bitPattern: code), radix: 16)))."
        case .mappingFailed(let message):
            return "hidutil n'a pas pu modifier les touches : \(message)"
        case .invalidKeyboard:
            return "Les identifiants de ce clavier sont invalides."
        case .onlyKeyboard:
            return "C'est le seul clavier détecté : le désactiver te laisserait sans clavier."
        }
    }
}
