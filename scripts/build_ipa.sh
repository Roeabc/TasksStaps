#!/usr/bin/env bash
# 在 Mac 上构建 TasksSteps 的「待自行签名」IPA。
#
#   SIGN_MODE=unsigned ./scripts/build_ipa.sh   # 默认：完全不签名，交给 Sideloadly/ESign 等重签
#   SIGN_MODE=adhoc    ./scripts/build_ipa.sh   # 先打一个 ad-hoc 占位签名
#
# 两种模式都不需要开发者证书、不需要描述文件。
# 产物：dist/TasksSteps-unsigned.ipa —— 不能直接安装，需先用签名工具重签。

set -euo pipefail

SCHEME="${SCHEME:-TasksSteps}"
PROJECT="${PROJECT:-TasksSteps.xcodeproj}"
CONFIG="${CONFIG:-Release}"
BUILD_DIR="${BUILD_DIR:-build}"
OUT_DIR="${OUT_DIR:-dist}"
IPA_NAME="${IPA_NAME:-TasksSteps-unsigned.ipa}"
SIGN_MODE="${SIGN_MODE:-unsigned}"

if [ ! -d "$PROJECT" ]; then
  if command -v xcodegen >/dev/null 2>&1; then
    echo "==> XcodeGen 生成 $PROJECT"
    xcodegen generate --spec project.yml
  else
    echo "!! 缺少 $PROJECT，且未安装 xcodegen（brew install xcodegen）" >&2
    exit 1
  fi
fi

# 新版 XcodeGen 会写 objectVersion = 77，Xcode 15.x 打不开这个工程格式
# （报 "future Xcode project file format (77)"，xcodebuild 退出码 74）。
# 这里按本机 Xcode 版本按需降级；工程格式本来就够老时脚本不会改动任何东西。
if [ -f scripts/normalize_project.py ]; then
  echo "==> 检查工程格式是否匹配本机 Xcode"
  python3 scripts/normalize_project.py "$PROJECT" --auto
fi

echo "==> 编译（签名模式: $SIGN_MODE）"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  clean build

APP="$BUILD_DIR/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
[ -d "$APP" ] || { echo "!! 未找到产物: $APP" >&2; exit 1; }

echo "==> 校验二进制"
lipo -info "$APP/$SCHEME"

if [ "$SIGN_MODE" = "adhoc" ]; then
  echo "==> ad-hoc 占位签名"
  /usr/bin/codesign --force --sign - --timestamp=none "$APP"
  /usr/bin/codesign --verify --verbose=2 "$APP" || true
fi

echo "==> 打包 IPA"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
# 只清扩展属性，保留 _CodeSignature（若有），否则签名会失效
xattr -cr "$OUT_DIR/Payload" 2>/dev/null || true

( cd "$OUT_DIR" && /usr/bin/zip -qry "$IPA_NAME" Payload -x ".*" -x "__MACOSX" )

echo "==> 完成"
ls -lh "$OUT_DIR/$IPA_NAME"
shasum -a 256 "$OUT_DIR/$IPA_NAME" | tee "$OUT_DIR/$IPA_NAME.sha256"
