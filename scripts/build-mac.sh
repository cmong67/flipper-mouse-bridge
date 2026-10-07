#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$project_dir/dist/Flipper Mouse Bridge.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/mac/Info.plist" "$app_dir/Contents/Info.plist"
swiftc "$project_dir/src/MouseBridge.swift" -o "$app_dir/Contents/MacOS/mouse-bridge" -framework CoreBluetooth -framework AppKit -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$project_dir/mac/Info.plist"
xattr -cr "$app_dir"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
"$app_dir/Contents/MacOS/mouse-bridge" --self-test
