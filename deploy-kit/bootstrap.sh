#!/usr/bin/env bash
# 大肥鱼一键引导（Linux / macOS / Windows Git-Bash 通用）
#
#   bash deploy-kit/bootstrap.sh                  # 装到 ./dafeiyu-astrbot
#   bash deploy-kit/bootstrap.sh ~/bots/dafeiyu   # 装到指定目录
#
# 它只做四件可验证的事：
#   1. 克隆（或更新）上游项目
#   2. 建虚拟环境、装插件依赖
#   3. 把插件/人格组装到 payload/（等拷进 AstrBot 数据目录）
#   4. 跑离线回归测试 + 前置检查
#
# 它不会、也无法替你做的事：装 AstrBot / NapCat、扫码登录 QQ、填 API 密钥。
set -euo pipefail

UPSTREAM="${UPSTREAM:-https://github.com/whyever77/dafeiyu-astrbot.git}"
TARGET_ARG="${1:-dafeiyu-astrbot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31m错误:\033[0m %s\n' "$*" >&2; exit 1; }
# Windows 原生程序（uv 等）看不懂 /c/... 这种 MSYS 路径，转一下
wpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
REQ="$(wpath "$ROOT/deploy-kit/requirements-plugin.txt")"

# --- 0. 路径归一：切到父目录，只用相对名，避开 Git-Bash 的路径转换 ---
BASE="$(basename "$TARGET_ARG")"
mkdir -p "$(dirname "$TARGET_ARG")"
cd "$(dirname "$TARGET_ARG")"
say "安装目录: $(pwd)/$BASE"

# --- 1. 代码 -----------------------------------------------------------------
if [ -d "$BASE/.git" ]; then
  say "更新已有仓库: $BASE"
  git -C "$BASE" pull --ff-only
else
  say "克隆上游: $UPSTREAM"
  git clone --depth 1 "$UPSTREAM" "$BASE"
fi

# --- 2. 虚拟环境 + 依赖（不 activate，直接调 venv 里的 python，最省事）------
VPY=""
if command -v uv >/dev/null 2>&1; then
  say "用 uv 建虚拟环境"
  uv venv --quiet "$BASE/.venv" ${PYVER:+--python "$PYVER"} || uv venv --quiet "$BASE/.venv"
fi
if [ -x "$BASE/.venv/bin/python" ]; then
  VPY="$(pwd)/$BASE/.venv/bin/python"
elif [ -x "$BASE/.venv/Scripts/python.exe" ]; then
  VPY="$(pwd)/$BASE/.venv/Scripts/python.exe"
else
  PY="${PYTHON:-python3}"
  command -v "$PY" >/dev/null 2>&1 || die "找不到 $PY，请先装 Python 3.10+"
  "$PY" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)' \
    || die "Python 版本太旧，需要 3.10+"
  say "用 $PY 建虚拟环境"
  "$PY" -m venv "$BASE/.venv" || die "venv 创建失败：Debian/Ubuntu 请先 apt install python3-venv"
  if [ -x "$BASE/.venv/bin/python" ]; then
    VPY="$(pwd)/$BASE/.venv/bin/python"
  elif [ -x "$BASE/.venv/Scripts/python.exe" ]; then
    VPY="$(pwd)/$BASE/.venv/Scripts/python.exe"
  fi
fi
[ -n "$VPY" ] || die "没能定位虚拟环境里的 python"

say "安装插件依赖"
if "$VPY" -m pip --version >/dev/null 2>&1; then
  "$VPY" -m pip install -q --upgrade pip
  "$VPY" -m pip install -q -r "$REQ"
elif command -v uv >/dev/null 2>&1; then
  # uv 建的 venv 默认不带 pip —— 直接用 uv 装
  uv pip install --python "$(wpath "$VPY")" -q -r "$REQ"
else
  "$VPY" -m ensurepip --upgrade >/dev/null 2>&1 || die "这个 Python 没有 pip，装不上依赖"
  "$VPY" -m pip install -q -r "$REQ"
fi

# --- 3. 组装 payload ---------------------------------------------------------
rm -rf "$BASE/payload"
mkdir -p "$BASE/payload/plugins" "$BASE/payload/persona"
cp -r "$BASE"/plugin/* "$BASE/payload/plugins/"
cp "$BASE"/persona/*.md "$BASE/payload/persona/"
say "已组装: $(pwd)/$BASE/payload"
say "  plugins/ → 拷进 AstrBot 数据目录的 data/plugins/"
say "  persona/ → 内容粘进 AstrBot 面板「人格」"

# --- 4. 自检 -----------------------------------------------------------------
say "跑离线回归测试（不花钱、不连 QQ）"
( cd "$BASE" && "$VPY" tests/test_face_rules.py && "$VPY" tests/test_schedule_awareness.py )
say "第三个测试需要 ffmpeg，可选：$VPY tests/test_video_processing.py"

say "跑前置检查"
"$VPY" "$(wpath "$ROOT/deploy-kit/preflight.py")" || true

cat <<'EOF'

=== 接下来只剩三件手工活 ===
 1. 装 AstrBot（Launcher 版）+ NapCat（Shell.Node 版），NapCat 用小号扫码
 2. AstrBot 里加 ws://127.0.0.1:6199/ws，配 DeepSeek / 百炼 提供商
 3. 把 payload/plugins/* 拷进 AstrBot 的 data/plugins/，重启

详见 QUICKSTART.md 与 README.md 第 2–6 章。
EOF
