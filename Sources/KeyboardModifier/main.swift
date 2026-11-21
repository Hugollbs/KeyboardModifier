import AppKit

// Le code de démarrage tourne sur le thread principal : on le déclare à Swift
MainActor.assumeIsolated {
    let app = NSApplication.shared
    // .accessory : pas d'icône dans le Dock, l'appli vit uniquement dans la barre de menus
    app.setActivationPolicy(.accessory)

    // app.delegate est une référence faible : on garde le delegate vivant ici pendant app.run()
    let delegate = AppDelegate()
    app.delegate = delegate

    // Ctrl+C / kill : on passe par terminate pour que applicationWillTerminate rende le clavier.
    // DispatchSource exécute le handler sur la file principale, pas dans le contexte du signal :
    // il n'y a donc pas de contrainte « async-signal-safe » à respecter.
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigint.setEventHandler { NSApp.terminate(nil) }
    sigterm.setEventHandler { NSApp.terminate(nil) }
    sigint.resume()
    sigterm.resume()

    app.run()
}
