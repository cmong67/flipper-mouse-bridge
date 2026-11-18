#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")/.."
stage=$(mktemp -d /tmp/hid-emu-tests.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 Tests/test_flipper.py
swiftc -swift-version 5 Sources/BridgeSupport.swift Sources/FlipperCommands.swift Sources/MouseInput.swift Tests/input_test.swift -o "$stage/input"
"$stage/input"

swiftc -swift-version 5 Sources/FirmwareUpdate.swift Tests/firmware_test.swift -o "$stage/firmware"
"$stage/firmware"
swiftc -swift-version 5 Sources/TargetFeedback.swift Tests/target_test.swift -o "$stage/target"
"$stage/target"
