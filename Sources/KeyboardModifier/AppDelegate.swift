import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var engine: Engine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = Engine(config: loadConfig())
        engine.start()
        self.engine = engine

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyboardModifier")

        let menu = NSMenu()
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}