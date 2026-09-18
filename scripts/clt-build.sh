#!/bin/zsh
# 用途:在 Xcode 27 的 swift-plugin-server 损坏期间,用 Command Line Tools 直接构建 Mote。
# 产物输出到项目约定的 Spotlight 可见位置: build/Build/Products/Release/Mote.app
# 不修改 project.yml / pbxproj;只绕过当前坏掉的 xcodebuild 宏插件链路。

set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/Build/Products/Release/Mote.app"
TMP="$(mktemp -d /tmp/mote-clt-build.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

CLT_DIR="/Library/Developer/CommandLineTools"
SWIFTC="${SWIFTC:-$CLT_DIR/usr/bin/swiftc}"
SDK="${SDK:-$CLT_DIR/SDKs/MacOSX.sdk}"
ACTOOL="${ACTOOL:-/Applications/Xcode.app/Contents/Developer/usr/bin/actool}"
TARGET="${TARGET:-arm64-apple-macosx14.0}"

if [[ ! -x "$SWIFTC" ]]; then
  echo "error: CLT swiftc not found: $SWIFTC" >&2
  exit 1
fi
if [[ ! -d "$SDK" ]]; then
  echo "error: macOS SDK not found: $SDK" >&2
  exit 1
fi
if [[ ! -x "$ACTOOL" ]]; then
  echo "error: actool not found: $ACTOOL" >&2
  exit 1
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "[1/5] compile assets"
"$ACTOOL" \
  --output-format human-readable-text \
  --platform macosx \
  --app-icon AppIcon \
  --minimum-deployment-target 14.0 \
  --output-partial-info-plist "$TMP/partial.plist" \
  --compile "$APP/Contents/Resources" \
  "$ROOT/Mote/Assets.xcassets" >/dev/null

echo "[2/5] compile & link"
"$SWIFTC" \
  -O \
  -sdk "$SDK" \
  -target "$TARGET" \
  -swift-version 5 \
  -o "$APP/Contents/MacOS/Mote" \
  "$ROOT"/Mote/App/*.swift \
  "$ROOT"/Mote/Documents/*.swift \
  "$ROOT"/Mote/Editor/*.swift \
  "$ROOT"/Mote/Encoding/*.swift \
  "$ROOT"/Mote/Highlighting/*.swift \
  "$ROOT"/Mote/Preview/*.swift \
  "$ROOT"/Mote/Vendor/Sourceful/**/*.swift

echo "[3/5] Info.plist"
sed \
  -e 's/\$(EXECUTABLE_NAME)/Mote/g' \
  -e 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.mote.app/g' \
  "$ROOT/Mote/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "[4/5] codesign"
codesign --force --sign - "$APP" >/dev/null

echo "[5/5] cleanup Debug.app to keep Spotlight clean"
rm -rf "$ROOT/build/Build/Products/Debug/Mote.app"

test -x "$APP/Contents/MacOS/Mote"
echo "OK: $APP"
