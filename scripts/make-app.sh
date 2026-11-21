#!/bin/zsh
# Construit KeyboardModifier.app (double-clic, sans terminal) dans .build/
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/KeyboardModifier"
APP=".build/KeyboardModifier.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/KeyboardModifier"
cp scripts/Info.plist "$APP/Contents/Info.plist"

# Signature ad hoc : donne une identité stable à l'appli pour les autorisations macOS
codesign --force --sign - "$APP"
echo "Appli créée : $APP"
