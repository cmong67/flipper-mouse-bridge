#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")"
stage=$(mktemp -d /tmp/mouse-bridge-build.XXXXXX)
app="$stage/HID Emu.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
swiftc -swift-version 5 -O Sources/*.swift -o "$app/Contents/MacOS/HIDEmu"
xattr -cr "$app"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
echo "$app"
if [[ "${1:-}" == '--install' ]]; then
 ditto "$app" "$HOME/Applications/HID Emu.app"
 xattr -cr "$HOME/Applications/HID Emu.app"
 codesign --force --deep --sign - "$HOME/Applications/HID Emu.app"
 codesign --verify --deep --strict "$HOME/Applications/HID Emu.app"
fi
