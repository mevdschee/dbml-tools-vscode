#!/usr/bin/env bash
#
# Publish the universal vsix/dbml-tools-<version>.vsix to the Visual Studio
# Marketplace and Open VSX.
#
# Requires (set in your shell or a .env loaded before invoking):
#   VSCE_PAT  — Visual Studio Marketplace PAT
#               (https://dev.azure.com/ → User Settings → PATs → Marketplace: Manage)
#   OVSX_PAT  — Open VSX access token
#               (https://open-vsx.org/user-settings/tokens)
#
# Usage:
#   ./scripts/publish-all.sh              # both registries (default)
#   ./scripts/publish-all.sh vsce         # marketplace only
#   ./scripts/publish-all.sh ovsx         # open-vsx only
#
# Prereq: vsix/dbml-tools-<version>.vsix already built — run
#   ./scripts/package-all.sh first.

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-both}"

VERSION=$(node -p "require('./package.json').version")
VSIX="vsix/dbml-tools-${VERSION}.vsix"

if [ ! -f "$VSIX" ]; then
  echo "$VSIX not found. Run ./scripts/package-all.sh first." >&2
  exit 1
fi

publish_vsce() {
  if [ -z "${VSCE_PAT:-}" ]; then
    echo "VSCE_PAT is not set — skipping Visual Studio Marketplace" >&2
    return
  fi
  echo "=== Visual Studio Marketplace ==="
  echo "→ vsce publish $VSIX"
  npx --no-install vsce publish --packagePath "$VSIX"
}

publish_ovsx() {
  if [ -z "${OVSX_PAT:-}" ]; then
    echo "OVSX_PAT is not set — skipping Open VSX" >&2
    return
  fi
  echo "=== Open VSX ==="
  echo "→ ovsx publish $VSIX"
  npx --no-install ovsx publish "$VSIX"
}

case "$TARGET" in
  both) publish_vsce; publish_ovsx ;;
  vsce) publish_vsce ;;
  ovsx) publish_ovsx ;;
  *) echo "Usage: $0 [both|vsce|ovsx]" >&2; exit 2 ;;
esac

echo
echo "done."
