# KeyboardModifier

Application macOS pour remapper les touches de claviers externes : ouvrir des applications, exécuter des commandes terminal, etc.



## Usage

- Build the app with `./scripts/make-app.sh` (creates `.build/KeyboardModifier.app`), drag it to `/Applications`, then double-click it: an icon appears in the menu bar (no Dock icon, no terminal).
- "Configurer…" : pick the keyboard, press "Ajouter" then a key on it, choose an app or a command, save.
- "Lancer à l'ouverture de session" : starts the app at login (keep the binary at a stable path).
- Allow the app in System Settings > Privacy & Security > Input Monitoring.
- Config file: `~/.config/keyboardmodifier/config.json`.
