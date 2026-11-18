#!/usr/bin/env bash
#
# Checks that a release build keeps the protections the project asks for: the sandbox, the
# hardened runtime, and no debugger attachment (which would also fail notarization and App
# Review). With --app-store it also checks what App Store Connect requires: an embedded
# provisioning profile and the application identifier it grants, without which the upload is
# rejected or the build can't be used in TestFlight.
#
# Usage: scripts/verify-signature.sh <path to .app> [--app-store]

set -euo pipefail

APP=${1:?Usage: scripts/verify-signature.sh <path to .app> [--app-store]}

codesign --verify --deep --strict --verbose=2 "$APP"

ENTITLEMENTS=$(mktemp)
trap 'rm -f "$ENTITLEMENTS"' EXIT
codesign -d --entitlements "$ENTITLEMENTS" --xml "$APP"
entitlement() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$ENTITLEMENTS" 2>/dev/null || echo missing
}

failed=0
if [ "$(entitlement com.apple.security.app-sandbox)" != "true" ]; then
  echo "::error::App Sandbox entitlement is missing"; failed=1
fi
if [ "$(entitlement com.apple.security.get-task-allow)" = "true" ]; then
  echo "::error::Release build allows debugger attachment (get-task-allow)"; failed=1
fi
signature=$(codesign -dv "$APP" 2>&1)
if [[ "$signature" != *"flags="*runtime* ]]; then
  echo "::error::Hardened runtime is not enabled"; failed=1
fi

if [ "${2:-}" = "--app-store" ]; then
  if [ ! -f "$APP/Contents/embedded.provisionprofile" ]; then
    echo "::error::No provisioning profile is embedded"; failed=1
  fi
  bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Contents/Info.plist")
  team_id=$(entitlement com.apple.developer.team-identifier)
  if [ "$(entitlement com.apple.application-identifier)" != "$team_id.$bundle_id" ]; then
    echo "::error::Application identifier entitlement doesn't match $team_id.$bundle_id"; failed=1
  fi
fi

codesign -d --entitlements - "$APP"
exit "$failed"
