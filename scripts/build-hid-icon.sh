#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")/.."
stage=$(mktemp -d /tmp/hid-emu-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/HIDEmu.iconset" unified/Resources
master=assets/icons/HID_Emu_App_Icon_2026-11-18_v01.png
for size in 16 32 128 256 512; do
 sips -z "$size" "$size" "$master" --out "$stage/HIDEmu.iconset/icon_${size}x${size}.png" >/dev/null
 double=$((size*2))
 sips -z "$double" "$double" "$master" --out "$stage/HIDEmu.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/HIDEmu.iconset" -o unified/Resources/HIDEmu.icns
