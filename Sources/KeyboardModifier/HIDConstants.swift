// Valeurs de la spécification USB HID utilisées dans le projet
enum HID {
    static let genericDesktopPage = 0x01   // page « bureau générique » : contient les claviers
    static let keyboardUsage = 0x06        // usage « clavier » dans cette page
    static let keyboardPage = 0x07         // page des touches (A, B, Espace…)
    static let keyUsages = 4...231         // codes des vraies touches (0 à 3 : codes d'erreur)

    // hidutil attend page et usage dans un seul entier : la page est dans les 32 bits de poids fort
    static let hidutilKeyboardPageBits = keyboardPage << 32
    static let hidutilNoKey = hidutilKeyboardPageBits // usage 0 : touche sans effet
}
