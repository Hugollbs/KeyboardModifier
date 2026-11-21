import Foundation

// Désactive (ou réactive) toutes les touches de CE clavier pour macOS avec hidutil.
// Notre lecture directe du clavier (IOHIDManager) reçoit quand même les touches.
struct HidutilMapping: KeyMappingController {
    func disableKeys(of keyboard: KeyboardID) throws {
        let mappings = HID.keyUsages.map { ["HIDKeyboardModifierMappingSrc": HID.hidutilKeyboardPageBits + $0,
                                             "HIDKeyboardModifierMappingDst": HID.hidutilNoKey] }
        try apply(mappings, to: keyboard)
    }

    func restoreKeys(of keyboard: KeyboardID) throws {
        try apply([], to: keyboard)
    }

    private func apply(_ mappings: [[String: Int]], to keyboard: KeyboardID) throws {
        // Les identifiants viennent de config.json : on les valide avant de les passer à hidutil
        guard keyboard.isValid else { throw EngineError.invalidKeyboard }
        let matching: [String: Int] = ["VendorID": keyboard.vendorID, "ProductID": keyboard.productID]
        guard let mappingJSON = jsonString(["UserKeyMapping": mappings]),
              let matchingJSON = jsonString(matching) else {
            throw EngineError.mappingFailed("JSON impossible à construire")
        }

        // Arguments en tableau, sans shell : rien de ce qui vient de la config n'est interprété
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--matching", matchingJSON, "--set", mappingJSON]
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        do {
            try process.run()
        } catch {
            throw EngineError.mappingFailed(error.localizedDescription)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw EngineError.mappingFailed("code \(process.terminationStatus) \(message)".trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func jsonString(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
