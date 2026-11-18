#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")/.."
stage=$(mktemp -d /tmp/cardputer-tests.XXXXXX)
trap 'rm -rf "$stage"' EXIT
for name in bridge host; do
    clang++ -std=c++17 -fsanitize=address,undefined -g "Tests/${name}_test.cpp" -o "$stage/$name"
    "$stage/$name"
done
swiftc Sources/MouseInput.swift Tests/mouse_input_test.swift -o "$stage/mouse"
"$stage/mouse"
