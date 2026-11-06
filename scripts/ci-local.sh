#!/usr/bin/env bash
# Local mirror of .github/workflows/ios.yml.
#
#   bash scripts/ci-local.sh            full gate (iOS build on macOS only)
#   bash scripts/ci-local.sh --static   static checks only; exit 0 on success
#
# Exit codes: 0 = requested gate passed; 1 = a check failed;
#             2 = static checks passed but the iOS build cannot run on this host.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE=full
if [ "${1:-}" = "--static" ]; then MODE=static; fi

echo "== static checks"
bash scripts/check-plan.sh
bash scripts/check-workflow.sh
bash scripts/check-evidence.sh
bash scripts/check-project.sh
for f in scripts/*.sh; do
  bash -n "$f"
done
echo "== static checks: PASS"

if [ "$MODE" = "static" ]; then
  exit 0
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo
  echo "== iOS build: SKIPPED (host is $(uname -s); xcodebuild requires macOS)"
  echo "This is NOT a green iOS gate. Run on macOS or in GitHub Actions."
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo
  echo "== iOS build: SKIPPED (xcodebuild not found)"
  exit 2
fi

PROJECT="${PROJECT:-FacetForge.xcodeproj}"
SCHEME="${SCHEME:-FacetForge}"

if [ ! -d "$PROJECT" ]; then
  echo
  echo "== iOS build: skeleton (no $PROJECT yet; phase 1 turns this on)"
  exit 0
fi

echo "== iOS build: $PROJECT / $SCHEME"
mkdir -p .dev-cache/xcode

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
  echo "FAIL: no available iPad simulator" >&2
  exit 1
fi

xcodebuild -list -project "$PROJECT" -json | tee .dev-cache/xcode/xcodebuild-list.json
rm -rf .dev-cache/xcode/Build.xcresult
set -o pipefail
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath .dev-cache/xcode/DerivedData \
  -clonedSourcePackagesDirPath .dev-cache/xcode/SourcePackages \
  -resultBundlePath .dev-cache/xcode/Build.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  | tee .dev-cache/xcode/xcodebuild.log

APP=$(find .dev-cache/xcode/DerivedData/Build/Products -name 'FacetForge.app' -type d | head -1)
if [ -z "$APP" ]; then
  echo "FAIL: no FacetForge.app product found" >&2
  exit 1
fi
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" | tee .dev-cache/xcode/launch.txt
sleep 5
xcrun simctl io "$UDID" screenshot .dev-cache/xcode/smoke.png
test -s .dev-cache/xcode/smoke.png
sips -g pixelWidth -g pixelHeight .dev-cache/xcode/smoke.png
echo "== iOS build: PASS (screenshot .dev-cache/xcode/smoke.png)"
