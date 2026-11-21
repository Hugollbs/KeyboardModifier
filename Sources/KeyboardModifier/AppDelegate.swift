import AppKit
import SwiftUI
import IOKit.hid

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var engine: Engine?
    private var configWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let engine = Engine(config: loadConfig())
        self.engine = engine
        startEngine(engine)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyboardModifier")

        let menu = NSMenu()
        let configure = NSMenuItem(title: "Configurer…", action: #selector(showConfig), keyEquivalent: ",")
        configure.target = self
        menu.addItem(configure)
        let login = NSMenuItem(title: "Lancer à l'ouverture de session", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quitter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    // Appelé aussi à la sortie par Ctrl+C : on rend les touches à macOS
    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    // Une seule fenêtre à la fois : au premier lancement c'est celle de macOS (demande d'accès),
    // notre alerte n'est montrée que si l'accès a été refusé avant
    private func startEngine(_ engine: Engine) {
        let type = kIOHIDRequestTypeListenEvent
        let before = IOHIDCheckAccess(type)
        if before == kIOHIDAccessTypeUnknown {
            _ = IOHIDRequestAccess(type)
        }
        if IOHIDCheckAccess(type) == kIOHIDAccessTypeGranted {
            if !engine.start() { showRestartAlert() }
        } else if before != kIOHIDAccessTypeUnknown {
            showPermissionAlert()
        }
    }

    private func showRestartAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Relance l'appli"
        alert.informativeText = "L'autorisation vient d'être accordée : quitte puis relance KeyboardModifier pour qu'elle soit prise en compte."
        alert.runModal()
    }

    // Sans fenêtre ni terminal, c'est le seul moyen de dire pourquoi l'appli ne fait rien
    private func showPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Autorisation requise"
        alert.informativeText = "Autorise KeyboardModifier dans Réglages Système > Confidentialité et sécurité > Surveillance de l'entrée, puis relance l'appli."
        alert.addButton(withTitle: "Ouvrir les réglages")
        alert.addButton(withTitle: "Quitter")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
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

    @objc private func showConfig() {
        guard let engine else { return }
        // Une seule fenêtre à la fois ; sinon on en recrée une avec les règles à jour
        if configWindow == nil {
            let model = ConfigModel(engine: engine)
            let window = NSWindow(contentViewController: NSHostingController(rootView: ConfigView(model: model)))
            window.title = "Configuration"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            configWindow = window
        }
        // L'appli n'a pas d'icône Dock : on l'active à la main pour que la fenêtre prenne le focus
        NSApp.activate(ignoringOtherApps: true)
        configWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        engine?.cancelCapture() // sinon la prochaine touche serait avalée
        configWindow = nil
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let enable = !isLaunchAtLoginEnabled()
        setLaunchAtLogin(enable)
        sender.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}