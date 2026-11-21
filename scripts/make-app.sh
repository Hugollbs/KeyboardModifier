#!/bin/zsh
# Construit KeyboardModifier.app (double-clic, sans terminal) dans .build/
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/KeyboardModifier"
APP=".build/KeyboardModifier.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/KeyboardModifier"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Signature ad hoc avec une exigence basée sur l'identifiant : sans elle, chaque recompilation
# change l'identité de l'appli et macOS oublie l'autorisation Surveillance de l'entrée
codesign --force --sign - -r='designated => identifier "com.hugollbs.keyboardmodifier"' "$APP"
echo "Appli créée : $APP"
