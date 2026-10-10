#!/bin/bash
# Runs the unit tests. With only the Command Line Tools, Swift Testing lives outside the default search paths.
set -euo pipefail
cd "$(dirname "$0")/.."
F=$(xcode-select -p)/Library/Developer/Frameworks
L=$(xcode-select -p)/Library/Developer/usr/lib
exec swift test -Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
