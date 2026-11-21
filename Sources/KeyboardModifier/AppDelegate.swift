import AppKit
import SwiftUI
import IOKit.hid

private let relaunchFlag = "--relaunched"

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var engine: Engine?
    private let popover = NSPopover()
    private var accessTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let engine = Engine(config: loadConfig())
        self.engine = engine
        startEngine(engine)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyboardModifier")

        // Clic : panneau sous l'icône ; clic droit : petit menu (Quitter)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover.behavior = .transient // se ferme quand on clique ailleurs
        popover.animates = true
        popover.delegate = self
        statusItem = item
    }

    // Appelé aussi à la sortie par Ctrl+C : on rend les touches à macOS
    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    // Au premier lancement, la fenêtre de macOS demande l'accès ; notre alerte n'est montrée
    // que si l'accès a été refusé avant. Dans tous les cas on attend l'autorisation,
    // pour démarrer dès qu'elle est cochée dans les réglages
    private func startEngine(_ engine: Engine) {
        let type = kIOHIDRequestTypeListenEvent
        let before = IOHIDCheckAccess(type)
        if before == kIOHIDAccessTypeUnknown {
            _ = IOHIDRequestAccess(type)
        }
        if IOHIDCheckAccess(type) == kIOHIDAccessTypeGranted {
            startOrRelaunch(engine)
            return
        }
        if before != kIOHIDAccessTypeUnknown {
            showPermissionAlert()
        }
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard IOHIDCheckAccess(type) == kIOHIDAccessTypeGranted else { return }
            timer.invalidate()
            self?.startOrRelaunch(engine)
        }
    }

    // macOS applique parfois l'autorisation seulement au prochain lancement :
    // si le démarrage échoue, on se relance une fois automatiquement
    private func startOrRelaunch(_ engine: Engine) {
        if engine.start() { return }
        guard !CommandLine.arguments.contains(relaunchFlag) else {
            showRestartAlert()
            return
        }
        // Le délai laisse l'ancienne instance quitter (et rendre le clavier) avant la nouvelle
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open -n \"\(Bundle.main.bundlePath)\" --args \(relaunchFlag)"]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func showRestartAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Impossible d'accéder au clavier"
        alert.informativeText = "Vérifie que KeyboardModifier est coché dans Surveillance de l'entrée, puis quitte et relance l'appli."
        alert.runModal()
    }

    // Sans fenêtre ni terminal, c'est le seul moyen de dire pourquoi l'appli ne fait rien
    private func showPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Autorisation requise"
        alert.informativeText = "Autorise KeyboardModifier dans Réglages Système > Confidentialité et sécurité > Surveillance de l'entrée. L'appli démarrera toute seule ensuite."
        alert.addButton(withTitle: "Ouvrir les réglages")
        alert.addButton(withTitle: "Plus tard")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // Sans icône Dock, l'appli n'a pas de menu Édition : ⌘C / ⌘V / ⌘X / ⌘A / ⌘Z
    // ne marchent pas dans les champs de texte tant qu'on ne le crée pas
    private func installEditMenu() {
        let edit = NSMenu(title: "Édition")
        edit.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = edit
        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(from: sender)
        }
    }

    // Un panneau neuf à chaque ouverture : il reflète toujours les règles enregistrées
    private func showPopover(from button: NSStatusBarButton) {
        guard let engine else { return }
        let view = PopoverView(model: ConfigModel(engine: engine),
                               close: { [weak self] in self?.popover.performClose(nil) })
        popover.contentViewController = NSHostingController(rootView: view)
        // L'appli n'a pas d'icône Dock : on l'active à la main pour que les champs prennent le focus
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quitter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // Le menu n'est attaché que le temps du clic, sinon il remplacerait le panneau
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func popoverDidClose(_ notification: Notification) {
        engine?.cancelCapture() // sinon la prochaine touche serait avalée
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}