import AppKit

let app = NSApplication.shared
// .accessory : pas d'icône dans le Dock, l'appli vit uniquement dans la barre de menus
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

// Ctrl+C / kill : on passe par terminate pour que applicationWillTerminate rende le clavier
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigint.setEventHandler { NSApp.terminate(nil) }
sigterm.setEventHandler { NSApp.terminate(nil) }
sigint.resume()
sigterm.resume()

app.run()
