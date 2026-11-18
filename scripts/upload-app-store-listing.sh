#!/usr/bin/env bash
#
# Uploads the App Store listing in appstore/ (name, subtitle, description, keywords, URLs,
# categories, copyright, App Review information and screenshots) to App Store Connect with
# fastlane deliver. It never uploads a build and never submits for review.
#
# Without a version it edits the version that is currently editable in App Store Connect
# ("Prepare for Submission"). With a version, such as 1.0.1, it creates that version first if
# it doesn't exist yet.
#
# Screenshots are synced: ones whose file is unchanged stay, changed ones are replaced, and
# ones that no longer exist in appstore/screenshots are removed from App Store Connect.
#
# Needs an App Store Connect API key with the App Manager role, in these environment variables:
#   APP_STORE_CONNECT_API_KEY     contents of the .p8 file
#   APP_STORE_CONNECT_KEY_ID
#   APP_STORE_CONNECT_ISSUER_ID
#
# The App Review contact phone number isn't in the repo, which is public. It's set once in App
# Store Connect, and the upload leaves it alone.
#
# Usage: bundle exec scripts/upload-app-store-listing.sh [version]

set -euo pipefail

VERSION=${1:-}
VERSION=${VERSION#v}  # tags are named v1.2.3
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${APP_STORE_CONNECT_API_KEY:?Set APP_STORE_CONNECT_API_KEY to the contents of the .p8 key}"
: "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID}"
: "${APP_STORE_CONNECT_ISSUER_ID:?Set APP_STORE_CONNECT_ISSUER_ID}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# deliver reads the key from a JSON file. Ruby is there anyway, since fastlane runs on it, and
# writes the JSON with proper escaping of the multi-line key.
ruby -rjson -e 'File.write(ARGV[0], JSON.generate(
  key_id: ENV["APP_STORE_CONNECT_KEY_ID"], issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
  key: ENV["APP_STORE_CONNECT_API_KEY"], in_house: false))' "$WORK/api_key.json"
# fastlane would otherwise take this variable for its own option of the same name, which
# expects a hash.
unset APP_STORE_CONNECT_API_KEY

ARGS=(
  "api_key_path:$WORK/api_key.json"
  app_identifier:com.juri1212.Duophonic
  platform:osx
  "metadata_path:$ROOT/appstore/metadata"
  "screenshots_path:$ROOT/appstore/screenshots"
  sync_screenshots:true
  skip_binary_upload:true
  submit_for_review:false
  run_precheck_before_submit:false
  force:true  # don't stop to ask for confirmation of the HTML preview
)
if [ -n "$VERSION" ]; then
  ARGS+=("app_version:$VERSION")
fi

# As an action rather than `fastlane deliver`, which wants a Deliverfile and asks to create one.
FASTLANE_ENABLE_BETA_DELIVER_SYNC_SCREENSHOTS=true FASTLANE_SKIP_UPDATE_CHECK=true \
  FASTLANE_HIDE_CHANGELOG=true FASTLANE_OPT_OUT_USAGE=true \
  fastlane run deliver "${ARGS[@]}"
