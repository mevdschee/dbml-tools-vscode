#!/usr/bin/env bash
#
# Package a single universal .vsix containing the dbml-tools binary for every
# supported platform. At install time the user gets all six binaries; at run
# time the extension picks server-bin/<platform>-<arch>/dbml-tools for the
# current OS.
#
# Prereq: cross-built binaries copied into server-bin/. Easiest way:
#   (in ../dbml-tools/) make sync-vscode VSCODE_DIR=../dbml-tools-vscode
#
# Output: vsix/dbml-tools-<version>.vsix

set -euo pipefail

cd "$(dirname "$0")/.."

ALL_TARGETS=(linux-x64 linux-arm64 darwin-x64 darwin-arm64 win32-x64 win32-arm64)

# Build the JS bundle.
npm run build

if [ ! -d server-bin ]; then
  echo "server-bin/ is missing — nothing to package" >&2
  echo "Run: (cd ../dbml-tools && make sync-vscode VSCODE_DIR=../dbml-tools-vscode)" >&2
  exit 1
fi

# Verify every target has its binary — otherwise users on that platform would
# install a broken extension.
missing=()
for t in "${ALL_TARGETS[@]}"; do
  bin="server-bin/$t/dbml-tools"
  case "$t" in win32-*) bin="$bin.exe" ;; esac
  if [ ! -f "$bin" ]; then
    missing+=("$t")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing binaries for: ${missing[*]}" >&2
  echo "Run: (cd ../dbml-tools && make sync-vscode VSCODE_DIR=../dbml-tools-vscode)" >&2
  exit 1
fi

mkdir -p vsix
npx --no-install vsce package --out vsix/ >/dev/null

echo
echo "vsix files:"
ls -1 vsix/*.vsix
