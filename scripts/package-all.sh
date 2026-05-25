#!/usr/bin/env bash
#
# Package a platform-specific .vsix for every target with a bundled
# dbml-tools binary already present under server-bin/<target>/.
#
# Each .vsix contains ONLY its target's binary — other platforms are staged
# out temporarily so they don't bloat the package.
#
# Usage:
#   ./scripts/package-all.sh                       # all targets that have a binary
#   ./scripts/package-all.sh linux-x64             # one target
#   ./scripts/package-all.sh --archive             # all targets + tar.gz bundle
#   ./scripts/package-all.sh --archive linux-x64   # one target + tar.gz bundle
#
# Prereq: cross-built binaries copied into server-bin/. Easiest way:
#   (in ../dbml-tools/) make sync-vscode VSCODE_DIR=../dbml-tools-vscode
#
# Output: vsix/dbml-tools-<version>-<target>.vsix
#         vsix/dbml-tools-<version>.tar.gz  (with --archive)

set -euo pipefail

cd "$(dirname "$0")/.."

ALL_TARGETS=(linux-x64 linux-arm64 darwin-x64 darwin-arm64 win32-x64 win32-arm64)
ARCHIVE=0
SELECTED=()
for arg in "$@"; do
  case "$arg" in
    --archive) ARCHIVE=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
    *) SELECTED+=("$arg") ;;
  esac
done
if [ ${#SELECTED[@]} -eq 0 ]; then
  SELECTED=("${ALL_TARGETS[@]}")
fi

# Build the JS bundle once.
npm run build

mkdir -p vsix

# Stash the full server-bin tree so we can temporarily swap in a target-only one.
if [ ! -d server-bin ]; then
  echo "server-bin/ is missing — nothing to package" >&2
  exit 1
fi
STASH=$(mktemp -d)
cp -r server-bin "$STASH/"

cleanup() {
  rm -rf server-bin
  mv "$STASH/server-bin" server-bin
  rm -rf "$STASH"
}
trap cleanup EXIT

for t in "${SELECTED[@]}"; do
  src_dir="$STASH/server-bin/$t"
  bin="$src_dir/dbml-tools"
  case "$t" in win32-*) bin="$bin.exe" ;; esac

  if [ ! -f "$bin" ]; then
    echo "skip $t — missing $bin"
    echo "  run: (cd ../dbml-tools && make sync-vscode)"
    continue
  fi

  # Replace server-bin/ with a tree containing only this target.
  rm -rf server-bin
  mkdir -p "server-bin/$t"
  cp "$bin" "server-bin/$t/"

  echo "→ packaging $t"
  npx --no-install vsce package --target "$t" --out "vsix/" >/dev/null
done

echo
echo "vsix files:"
ls -1 vsix/*.vsix 2>/dev/null || echo "  (none produced)"

if [ "$ARCHIVE" -eq 1 ]; then
  shopt -s nullglob
  vsix_files=(vsix/*.vsix)
  shopt -u nullglob
  if [ ${#vsix_files[@]} -eq 0 ]; then
    echo "no .vsix files to archive" >&2
    exit 1
  fi
  version=$(node -p "require('./package.json').version")
  archive="vsix/dbml-tools-${version}.tar.gz"
  tar -czf "$archive" -C vsix $(printf '%s\n' "${vsix_files[@]}" | xargs -n1 basename)
  echo
  echo "archive: $archive"
fi
