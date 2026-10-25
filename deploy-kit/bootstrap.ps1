# 大肥鱼一键引导（Windows PowerShell）
#
#   powershell -ExecutionPolicy Bypass -File deploy-kit\bootstrap.ps1
#   powershell -ExecutionPolicy Bypass -File deploy-kit\bootstrap.ps1 -Target D:\dfy
#
# 只做四件可验证的事：克隆/更新上游 → 建 venv 装依赖 → 组装 payload → 跑离线测试。
# 装 AstrBot/NapCat、扫码登录、填密钥这三件必须你手工做。

param(
    [string]$Target = "dafeiyu-astrbot",
    [string]$Upstream = "https://github.com/whyever77/dafeiyu-astrbot.git"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Say($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- 1. 代码 ---
if (Test-Path (Join-Path $Target ".git")) {
    Say "更新已有仓库: $Target"
    git -C $Target pull --ff-only
} else {
    Say "克隆上游: $Upstream -> $Target"
    git clone --depth 1 $Upstream $Target
}

# --- 2. 依赖 ---
$venv = Join-Path $Target ".venv"
if (-not (Test-Path $venv)) {
    Say "创建虚拟环境"
    python -m venv $venv
}
$py = Join-Path $venv "Scripts\python.exe"
Say "安装插件依赖"
& $py -m pip install -q --upgrade pip
& $py -m pip install -q -r (Join-Path $Root "deploy-kit\requirements-plugin.txt")

# --- 3. 组装 payload ---
$payload = Join-Path $Target "payload"
if (Test-Path $payload) { Remove-Item $payload -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $payload "plugins"), (Join-Path $payload "persona") | Out-Null
Copy-Item (Join-Path $Target "plugin\*") (Join-Path $payload "plugins") -Recurse -Force
Copy-Item (Join-Path $Target "persona\*.md") (Join-Path $payload "persona") -Force
Say "已组装: $payload"
Say "  plugins\ → 拷进 AstrBot 数据目录的 data\plugins\"
Say "  persona\ → 内容粘进 AstrBot 面板「人格」"

# --- 4. 自检 ---
Say "跑离线回归测试（不花钱、不连 QQ）"
Push-Location $Target
& $py tests\test_face_rules.py
& $py tests\test_schedule_awareness.py
Pop-Location

Say "跑前置检查"
& $py (Join-Path $Root "deploy-kit\preflight.py")

Write-Host @"

=== 接下来只剩三件手工活 ===
 1. 装 AstrBot（Launcher 版）+ NapCat（Shell.Node 版），NapCat 用小号扫码
 2. AstrBot 里加 ws://127.0.0.1:6199/ws，配 DeepSeek / 百炼 提供商
 3. 把 payload\plugins\* 拷进 AstrBot 的 data\plugins\，重启

详见 QUICKSTART.md 与 README.md 第 2–6 章。
"@ -ForegroundColor Yellow
