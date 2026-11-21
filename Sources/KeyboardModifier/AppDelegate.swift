import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var engine: Engine?
    private var configWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = Engine(config: loadConfig())
        engine.start()
        self.engine = engine

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyboardModifier")

        let menu = NSMenu()
        let configure = NSMenuItem(title: "Configurer…", action: #selector(showConfig), keyEquivalent: ",")
        configure.target = self
        menu.addItem(configure)
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}