import Foundation

private let keyboardPage = 0x7_0000_0000
private let nothing = 0x7_0000_0000     

// Désactive (ou réactive) toutes les touches de CE clavier pour macOS.
// Notre lecture directe du clavier (IOHIDManager) reçoit quand même les touches.
func setKeysDisabled(_ disabled: Bool, for keyboard: KeyboardID) {
    let mappings: [[String: Int]] = disabled
        ? (4...231).map { ["HIDKeyboardModifierMappingSrc": keyboardPage + $0,
                           "HIDKeyboardModifierMappingDst": nothing] }
        : []
    let payload: [String: Any] = ["UserKeyMapping": mappings]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else {
        print("Impossible de construire le JSON pour hidutil")
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    process.arguments = ["property",
                         "--matching", "{\"VendorID\":\(keyboard.vendorID),\"ProductID\":\(keyboard.productID)}",
                         "--set", json]
    process.standardOutput = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { print("hidutil a échoué (code \(process.terminationStatus))") }
    } catch {
        print("Impossible de lancer hidutil : \(error)")
    }
}
