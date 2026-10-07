#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_root=$(mktemp -d "${TMPDIR:-/tmp}/flipper-build.XXXXXX")
app_dir="$build_root/Flipper Mouse Bridge.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/mac/Info.plist" "$app_dir/Contents/Info.plist"
swiftc "$project_dir"/src/*.swift -o "$app_dir/Contents/MacOS/mouse-bridge" -framework CoreBluetooth -framework AppKit -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$project_dir/mac/Info.plist"
xattr -cr "$app_dir"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
"$app_dir/Contents/MacOS/mouse-bridge" --self-test

mkdir -p "$project_dir/dist"
ditto "$app_dir" "$project_dir/dist/Flipper Mouse Bridge.app"
printf "Verified build: %s\n" "$app_dir"
