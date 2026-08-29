#!/bin/bash
# Mote 一键安装：下载最新 Release → 移除 Gatekeeper 隔离标记 → 安装到「应用程序」→ 启动
#
# 用法（官网按钮复制的命令即此）：
#   curl -fsSL https://zhangqixiang-sh.github.io/Mote/install.sh | bash
#
# 可选环境变量：MOTE_INSTALL_DIR=/path/to/dir  安装到自定义目录（默认 /Applications）

set -euo pipefail

APP_NAME="Mote"
REPO="zhangqixiang-sh/Mote"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}-macOS.zip"
INSTALL_DIR="${MOTE_INSTALL_DIR:-/Applications}"

# 终端里才上色，重定向到日志时输出纯文本
if [ -t 1 ]; then
  BOLD=$'\033[1m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; RED=$'\033[31m'; OFF=$'\033[0m'
else
  BOLD=""; CYAN=""; GREEN=""; RED=""; OFF=""
fi

info() { printf '%s==>%s %s\n' "${CYAN}${BOLD}" "${OFF}" "$1"; }
ok()   { printf '%s%s%s\n' "${GREEN}${BOLD}" "$1" "${OFF}"; }
die()  { printf '%s错误：%s%s\n' "${RED}${BOLD}" "${OFF}" "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "此脚本仅支持 macOS。"

# 当前 Release 只提供 Apple Silicon（arm64）构建
[ "$(uname -m)" = "arm64" ] || die "当前版本仅支持 Apple Silicon（M 系列）芯片，Intel Mac 请从源码构建：https://github.com/${REPO}#构建"

MAC_VER="$(sw_vers -productVersion)"
if [ "$(printf '%s\n14.0\n%s\n' "$MAC_VER" | sort -V | head -n 2 | tail -n 1)" != "14.0" ]; then
  die "需要 macOS 14.0 或更高版本（当前为 ${MAC_VER}）。"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

info "下载最新版 ${APP_NAME}…"
curl -fSL --progress-bar "$ZIP_URL" -o "$TMP_DIR/${APP_NAME}-macOS.zip" || die "下载失败，请检查网络后重试。"

info "解压…"
ditto -x -k "$TMP_DIR/${APP_NAME}-macOS.zip" "$TMP_DIR"

SRC_APP="$TMP_DIR/${APP_NAME}.app"
[ -d "$SRC_APP" ] || die "下载内容异常（未找到 ${APP_NAME}.app），请到 https://github.com/${REPO}/issues 反馈。"

DEST_APP="$INSTALL_DIR/${APP_NAME}.app"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  info "检测到 ${APP_NAME} 正在运行，先请它退出…"
  osascript -e "quit app \"${APP_NAME}\"" >/dev/null 2>&1 || true
  sleep 1
fi

info "移除 Gatekeeper 隔离标记…"
# curl 下载本身不会打隔离标记，这里兜底清理，保证无论什么环境都无 Gatekeeper 弹窗
xattr -cr "$SRC_APP"

info "安装到 ${INSTALL_DIR} …"
if [ -e "$DEST_APP" ] || [ -L "$DEST_APP" ]; then
  rm -rf "$DEST_APP" 2>/dev/null || sudo rm -rf "$DEST_APP"
fi
if [ -d "$INSTALL_DIR" ] && [ -w "$INSTALL_DIR" ]; then
  ditto "$SRC_APP" "$DEST_APP"
else
  info "需要管理员权限写入 ${INSTALL_DIR}…"
  sudo mkdir -p "$INSTALL_DIR"
  sudo ditto "$SRC_APP" "$DEST_APP"
fi

# 立即注册到 LaunchServices，免去等待系统索引
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST_APP" 2>/dev/null || true

ok "✅ ${APP_NAME} 已安装到 ${DEST_APP}"

info "启动 ${APP_NAME}…"
open "$DEST_APP"
