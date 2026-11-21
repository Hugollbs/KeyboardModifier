import Foundation

// Désactive (ou réactive) toutes les touches de CE clavier pour macOS.
// Notre lecture directe du clavier (IOHIDManager) reçoit quand même les touches.
func setKeysDisabled(_ disabled: Bool, for keyboard: KeyboardID) {
    // Les identifiants viennent de config.json : on les valide avant de les passer à hidutil
    guard keyboard.isValid else {
        log.error("Identifiants de clavier invalides : \(keyboard.vendorID)/\(keyboard.productID)")
        return
    }
    let mappings: [[String: Int]] = disabled
        ? HID.keyUsages.map { ["HIDKeyboardModifierMappingSrc": HID.hidutilKeyboardPageBits + $0,
                               "HIDKeyboardModifierMappingDst": HID.hidutilNoKey] }
        : []
    let matching: [String: Int] = ["VendorID": keyboard.vendorID, "ProductID": keyboard.productID]
    guard let mappingJSON = jsonString(["UserKeyMapping": mappings]),
          let matchingJSON = jsonString(matching) else {
        log.error("Impossible de construire le JSON pour hidutil")
        return
    }

    // Arguments en tableau, sans shell : rien de ce qui vient de la config n'est interprété
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    process.arguments = ["property", "--matching", matchingJSON, "--set", mappingJSON]
    process.standardOutput = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { log.error("hidutil a échoué (code \(process.terminationStatus))") }
    } catch {
        log.error("Impossible de lancer hidutil : \(error.localizedDescription)")
    }
}

private func jsonString(_ object: Any) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
    return String(data: data, encoding: .utf8)
}
