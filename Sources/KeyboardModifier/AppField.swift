import AppKit
import SwiftUI

// Champ de texte avec la complétion native de macOS : la liste des applications s'ouvre
// sous le champ dans sa propre fenêtre, donc elle peut dépasser de la fenêtre de configuration.
struct AppField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let autofocus: Bool
    let onChosen: () -> Void // le texte est devenu le nom exact d'une appli

    func makeNSView(context: Context) -> CompletingTextField {
        let field = CompletingTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: CompletingTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        if autofocus && !context.coordinator.didAutofocus {
            context.coordinator.didAutofocus = true
            // Attendre que la vue soit dans la fenêtre avant de lui donner le focus
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onChosen: onChosen) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onChosen: () -> Void
        var didAutofocus = false
        private var isDeleting = false

        init(text: Binding<String>, onChosen: @escaping () -> Void) {
            self.text = text
            self.onChosen = onChosen
        }

        // Un nom d'appli complet et sans suite possible : le choix est fait
        private func isChosen(_ name: String) -> Bool {
            appPath(named: name) != nil
                && installedApps.filter { $0.range(of: name, options: [.anchored, .caseInsensitive]) != nil }.count == 1
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if isChosen(text.wrappedValue) { onChosen() }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
            // Après un effacement on ne rouvre pas la liste, sinon elle gêne la correction
            if isDeleting { isDeleting = false; return }
            if isChosen(field.stringValue) {
                // Fermer la liste et quitter le champ, la ligne affichera l'icône de l'appli
                DispatchQueue.main.async {
                    field.window?.makeFirstResponder(nil)
                    self.onChosen()
                }
                return
            }
            (field.currentEditor() as? NSTextView)?.complete(nil)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.deleteBackward(_:)) || selector == #selector(NSResponder.deleteForward(_:)) {
                isDeleting = true
            }
            return false
        }

        // Appelé par macOS pour remplir la liste ; -1 = aucune ligne présélectionnée,
        // donc rien n'est inséré dans le champ tant qu'on n'a pas choisi
        func control(_ control: NSControl, textView: NSTextView, completions words: [String],
                     forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
            index.pointee = -1
            return appNames(matching: textView.string)
        }
    }
}

// Noms d'applications contenant le texte, ceux qui commencent par le texte en premier
func appNames(matching search: String) -> [String] {
    guard !search.isEmpty else { return installedApps }
    let found = installedApps.filter { $0.localizedCaseInsensitiveContains(search) }
    let starting = found.filter { $0.range(of: search, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil }
    return starting + found.filter { !starting.contains($0) }
}

// Ouvre la liste dès que le champ prend le focus, même vide
final class CompletingTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            DispatchQueue.main.async { [weak self] in
                (self?.currentEditor() as? NSTextView)?.complete(nil)
            }
        }
        return accepted
    }
}

// Par défaut macOS ne remplace que le dernier mot tapé ; les noms d'applis ont des espaces
// (« Visual Studio Code »), donc la complétion doit remplacer tout le champ
final class WholeFieldEditor: NSTextView {
    override var rangeForUserCompletion: NSRange {
        NSRange(location: 0, length: (string as NSString).length)
    }
}
