import AppKit
import SwiftUI
import IOKit.hid

private let relaunchFlag = "--relaunched"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var engine: Engine?
    private var configWindow: NSWindow?
    private let appFieldEditor: NSTextView = {
        let editor = WholeFieldEditor()
        editor.isFieldEditor = true
        return editor
    }()
    private var accessTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let config: Config
        do {
            config = try loadConfig()
        } catch {
            // Sortie normale (code 0), sinon le LaunchAgent relancerait l'appli en boucle
            showError("Configuration illisible", error)
            NSApp.terminate(nil)
            return
        }
        let engine = Engine(config: config)
        self.engine = engine
        engine.restoreLeftoverMapping() // rend le clavier si l'appli précédente a été tuée
        startEngine(engine)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyboardModifier")

        let menu = NSMenu()
        let configure = NSMenuItem(title: "Configurer…", action: #selector(showConfig), keyEquivalent: ",")
        configure.target = self
        menu.addItem(configure)
        let release = NSMenuItem(title: "Rendre le clavier à macOS", action: #selector(toggleKeyboardControl(_:)), keyEquivalent: "")
        release.target = self
        menu.addItem(release)
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
            // Le timer est sur le run loop principal
            MainActor.assumeIsolated { self?.startOrRelaunch(engine) }
        }
    }

    // macOS applique parfois l'autorisation seulement au prochain lancement :
    // si le démarrage échoue, on se relance une fois automatiquement
    private func startOrRelaunch(_ engine: Engine) {
        do {
            try engine.start()
            return
        } catch let error as EngineError where error.isAccessProblem {
            log.error("Démarrage impossible : \(error.localizedDescription)")
        } catch {
            showError("Le clavier n'a pas pu être désactivé", error)
            return
        }
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

    private func showError(_ title: String, _ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
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

    // Les champs d'application utilisent un éditeur de texte qui complète tout le champ
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        client is CompletingTextField ? appFieldEditor : nil
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

    // Sortie de secours : rend le clavier à macOS sans quitter l'appli, puis le reprend à la demande
    @objc private func toggleKeyboardControl(_ sender: NSMenuItem) {
        guard let engine else { return }
        if engine.isActive {
            engine.stop()
            sender.title = "Reprendre le contrôle du clavier"
        } else {
            do {
                try engine.start()
                sender.title = "Rendre le clavier à macOS"
            } catch {
                showError("Le clavier n'a pas pu être désactivé", error)
            }
        }
    }

    // Après une veille, macOS recrée le clavier et le mapping hidutil est perdu : les touches
    // s'écrivent de nouveau. On le ré-applique, avec un délai pour laisser le clavier réapparaître.
    @objc private func didWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            MainActor.assumeIsolated {
                guard let engine = self?.engine, engine.isActive else { return } // pas si rendu à macOS
                do {
                    try engine.start()
                } catch {
                    log.error("Redémarrage après veille impossible : \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}