// Un événement HID est-il l'appui d'une vraie touche de clavier ? Si oui, renvoie son code.
// Fonction pure (sans IOKit) pour pouvoir la tester.
func pressedKey(page: Int, usage: Int, value: Int) -> Int? {
    guard page == HID.keyboardPage else { return nil }        // pas une touche (ex : molette, média)
    guard HID.keyUsages.contains(usage) else { return nil }   // codes d'erreur ou modificateurs hors plage
    guard value != 0 else { return nil }                      // on ne réagit qu'à l'appui, pas au relâchement
    return usage
}
