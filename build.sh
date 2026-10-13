#!/usr/bin/env bash
#
# 不依赖 Xcode 工程，直接用 swiftc 构建 BrowserPicker.app。
# 只需要 Xcode 或 Command Line Tools（xcode-select --install）。
#
# 用法：
#   ./build.sh            构建到 build/BrowserPicker.app（当前机器架构）
#   ./build.sh run        构建并运行
#   ./build.sh install    构建并安装到 /Applications，然后启动
#   UNIVERSAL=1 ./build.sh   构建 arm64 + x86_64 通用二进制
#   BUNDLE_ID=com.yourname.BrowserPicker ./build.sh   自定义 Bundle ID
#
set -euo pipefail

APP_NAME="BrowserPicker"
BUNDLE_ID="${BUNDLE_ID:-com.example.BrowserPicker}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_MACOS="13.0"

cd "$(dirname "$0")"
BUILD_DIR="$(pwd)/build"
APP="$BUILD_DIR/$APP_NAME.app"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "未找到 swiftc。请先安装 Xcode，或执行：xcode-select --install" >&2
  exit 1
fi

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCHS=(arm64 x86_64)
else
  ARCHS=("$(uname -m)")
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"

echo "==> 清理并创建 App 目录结构"
rm -rf "$APP" "$BUILD_DIR/obj"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/obj"

echo "==> 编译 Swift 源码（${ARCHS[*]}）"
BINS=()
for arch in "${ARCHS[@]}"; do
  out="$BUILD_DIR/obj/$APP_NAME-$arch"
  swiftc -O -parse-as-library \
    -sdk "$SDK" \
    -target "$arch-apple-macos$MIN_MACOS" \
    -module-name "$APP_NAME" \
    Sources/*.swift \
    -o "$out"
  BINS+=("$out")
done

if (( ${#BINS[@]} > 1 )); then
  lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
else
  cp "${BINS[0]}" "$APP/Contents/MacOS/$APP_NAME"
fi

echo "==> 生成 Info.plist"
PLIST="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
cp Config/Info.plist "$PLIST"
"$PB" -c "Set :CFBundleExecutable $APP_NAME" "$PLIST"
"$PB" -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
"$PB" -c "Set :CFBundleName $APP_NAME" "$PLIST"
"$PB" -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
"$PB" -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
"$PB" -c "Set :LSMinimumSystemVersion $MIN_MACOS" "$PLIST"
"$PB" -c "Add :CFBundleIconFile string AppIcon" "$PLIST" 2>/dev/null || true

echo "==> 生成图标"
ICON_DIR="Resources/Assets.xcassets/AppIcon.appiconset"
if ls "$ICON_DIR"/icon_*.png >/dev/null 2>&1; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  cp "$ICON_DIR"/icon_*.png "$ICONSET/"
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP"

echo "==> 完成：$APP"

case "${1:-}" in
  run)
    open "$APP"
    ;;
  install)
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/"
    open "/Applications/$APP_NAME.app"
    echo "已安装到 /Applications。请在 系统设置 → 桌面与程序坞 → 默认网页浏览器 中选择 $APP_NAME。"
    ;;
esac
