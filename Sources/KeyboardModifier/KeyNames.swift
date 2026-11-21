func keyName(_ usage: Int) -> String {
    switch usage {
    case 4...29: return String(UnicodeScalar(UInt8(65 + usage - 4)))   // A...Z
    case 30...38: return String(usage - 29)                            // 1...9
    case 39: return "0"
    case 40: return "Entrée"
    case 41: return "Échap"
    case 42: return "Retour arrière"
    case 43: return "Tab"
    case 44: return "Espace"
    case 58...69: return "F\(usage - 57)"
    case 79: return "Flèche →"
    case 80: return "Flèche ←"
    case 81: return "Flèche ↓"
    case 82: return "Flèche ↑"
    default: return "Touche \(usage)"
    }
}