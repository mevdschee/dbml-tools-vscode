#!/usr/bin/env bash
#
# Publish every vsix/*.vsix to the Visual Studio Marketplace and Open VSX.
#
# Each .vsix already encodes its platform target, so both registries merge
# the uploads into one extension listing that "works with" every platform.
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
# Prereq: vsix/*.vsix already built — run ./scripts/package-all.sh first.

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-both}"

shopt -s nullglob
VSIX_FILES=(vsix/*.vsix)
if [ ${#VSIX_FILES[@]} -eq 0 ]; then
  echo "No .vsix files in vsix/. Run ./scripts/package-all.sh first." >&2
  exit 1
fi

publish_vsce() {
  if [ -z "${VSCE_PAT:-}" ]; then
    echo "VSCE_PAT is not set — skipping Visual Studio Marketplace" >&2
    return
  fi
  echo "=== Visual Studio Marketplace ==="
  for f in "${VSIX_FILES[@]}"; do
    echo "→ vsce publish $f"
    if ! npx --no-install vsce publish --packagePath "$f"; then
      echo "  vsce failed for $f — continuing with remaining targets" >&2
    fi
  done
}

publish_ovsx() {
  if [ -z "${OVSX_PAT:-}" ]; then
    echo "OVSX_PAT is not set — skipping Open VSX" >&2
    return
  fi
  echo "=== Open VSX ==="
  for f in "${VSIX_FILES[@]}"; do
    echo "→ ovsx publish $f"
    if ! npx --no-install ovsx publish "$f"; then
      echo "  ovsx failed for $f — continuing with remaining targets" >&2
    fi
  done
}

case "$TARGET" in
  both) publish_vsce; publish_ovsx ;;
  vsce) publish_vsce ;;
  ovsx) publish_ovsx ;;
  *) echo "Usage: $0 [both|vsce|ovsx]" >&2; exit 2 ;;
esac

echo
echo "done."
