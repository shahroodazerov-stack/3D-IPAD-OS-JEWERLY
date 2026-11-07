#!/usr/bin/env bash
# Review and rewrite Phase 22's render snapshot baselines.
#
# This is the only supported way to change a baseline. The normal gate never
# passes --update-baselines, so a drift fails the run; this script runs the
# dedicated scheme whose TestAction passes the flag to the test process.
#
#   bash scripts/render-baselines.sh --update-baselines
#
# Requires macOS with Xcode 26 and an available iPad simulator. The script
# rewrites FacetForgeTests/Baselines/render-snapshots.json, appends to
# docs/evidence/render-snapshots.md and leaves diff images under
# .dev-cache/render-baselines/. Review and commit the two tracked files.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" != "--update-baselines" ]; then
  cat >&2 <<'USAGE'
render-baselines: refusing to run without the explicit flag.

Usage:
  bash scripts/render-baselines.sh --update-baselines

Without that argument the gate only compares against the committed baseline and
fails on drift. The flag is passed to the test process by the dedicated
FacetForgeBaselines scheme, never by .github/workflows/ios.yml.
USAGE
  exit 2
fi

if [ "$(uname -s)" != "Darwin" ] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "render-baselines: requires macOS with Xcode 26; this host cannot render Metal snapshots." >&2
  exit 2
fi

PROJECT="${PROJECT:-FacetForge.xcodeproj}"
SCHEME="FacetForgeBaselines"
mkdir -p .build .dev-cache/xcode .dev-cache/render-baselines

UDID=$(xcrun simctl list devices available -j | ruby -rjson -e '
  devices = JSON.parse(STDIN.read)["devices"]
  pick = nil
  devices.each do |runtime, list|
    next unless runtime.include?("iOS")
    list.each { |d| pick = d if pick.nil? && d["name"].match?(/iPad/) }
  end
  puts(pick ? pick["udid"] : "")
')
if [ -z "$UDID" ]; then
  echo "render-baselines: no available iPad simulator on this machine." >&2
  exit 1
fi

echo "== render baselines: $SCHEME on $UDID"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath .build/BaselinesDerivedData \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 240 \
  -maximum-test-execution-time-allowance 600 \
  -only-testing:FacetForgeTests/Phase22SnapshotHarnessTests \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  | tee .build/render-baselines.log

echo
echo "== review"
echo "  git diff -- FacetForgeTests/Baselines docs/evidence/render-snapshots.md"
echo "  diff images: .dev-cache/render-baselines/"
echo "Commit both tracked files with the reason for the change. The next normal gate compares"
echo "against the committed hashes; this script does not run that comparison for you."
