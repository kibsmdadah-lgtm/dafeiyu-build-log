# ⚡ QUICKSTART · 十条命令

> 目标：从空机器到「QQ 里发一句在吗，有人回你」。
> 全程约 40 分钟，其中 25 分钟是下载和扫码。
> 详细解释在 [README.md](README.md)，出问题看第 14 章故障速查。

---

## 第 0 步：前置检查（1 分钟）

```bash
git clone https://github.com/kibsmdadah-lgtm/dafeiyu-build-log.git
cd dafeiyu-build-log
python deploy-kit/preflight.py
```

红叉（阻塞项）先解决，黄色感叹号（提醒）可以先忽略。

---

## 第 1 步：拉项目 + 装依赖 + 自检（5 分钟）

```bash
# Linux / macOS / Windows Git-Bash
bash deploy-kit/bootstrap.sh
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File deploy-kit\bootstrap.ps1
```

它会克隆上游项目、建虚拟环境、装依赖、组装出一个 `payload/` 目录，
最后跑一遍离线测试——看到 **`结果：全部通过 OK`** 就说明拉下来的东西是好的。

---

## 第 2 步：填密钥（3 分钟）

```bash
cp deploy-kit/env.example .env      # PowerShell: Copy-Item deploy-kit\env.example .env
```

至少填两个：

| 变量 | 去哪拿 |
|---|---|
| `DEEPSEEK_API_KEY` | https://platform.deepseek.com |
| `DASHSCOPE_API_KEY` | https://bailian.console.aliyun.com → API-KEY 管理 |

填完复查：`python deploy-kit/preflight.py --env .env`

---

## 第 3 步：装 AstrBot（大脑，10 分钟）

1. 下载 **AstrBot Launcher**（图形化，自带隔离环境），装好启动
2. 国内网络：进「高级 → 通用」，打开 **中国大陆一键加速**
3. 面板打开 `http://localhost:6185`，设置管理员账号

## 第 4 步：装 NapCat（协议端，10 分钟）

1. 下载 `NapCat.Shell.Windows.Node.zip`（自带 Node）
2. 用 `launcher-win10-user.bat` 启动（免管理员）
3. WebUI `http://127.0.0.1:6099` → **用 QQ 小号扫码登录**

## 第 5 步：两边接起来（2 分钟）

NapCat WebUI 或 `config/onebot11_<QQ号>.json` 里加一个 websocket 客户端：

```json
{ "name": "astrbot", "url": "ws://127.0.0.1:6199/ws", "enable": true }
```

AstrBot 侧：平台适配器选 **QQ(aiocqhttp)**，端口 **6199**。

## 第 6 步：配三个提供商（3 分钟）

| 位置 | 填什么 |
|---|---|
| 对话模型 | `deepseek-chat` + DeepSeek Key |
| 图片转述 | `qwen3-vl-plus` + 百炼 Key |
| 语音（TTS） | `qwen-audio-3.1-tts-flash` + 百炼 Key（要自定义音色见 README 第 6 章） |

## 第 7 步：装插件 + 人格（3 分钟）

```bash
# 把 payload 里的东西拷进 AstrBot 数据目录
cp -r dafeiyu-astrbot/payload/plugins/*  <AstrBot数据目录>/data/plugins/
```

数据目录：Launcher 版在 `…/instances/<实例id>/core/data/`；手动部署版在 AstrBot 根目录 `data/`。

人格：面板 → 配置 → 人格 → 新建，名称 `大肥鱼`，
把 `dafeiyu-astrbot/payload/persona/大肥鱼-人格.md` 里 `---` 之后的正文整段粘进去，设为默认。

重启 AstrBot。

## 第 8 步：白名单（1 分钟，别跳过）

AstrBot 面板 → 访问控制 → 只放行 `<你的会话>`。
私聊发 `/sid` 能拿到自己的 UMO，形如 `qq:FriendMessage:<你的QQ>`。

## 第 9 步：验收（2 分钟）

| 发什么 | 应该发生什么 |
|---|---|
| 「在吗」 | 有文字回复，带真表情 |
| 一张图 | 她描述得出内容 |
| 一个纯表情 | 她有反应，不是装死 |
| `/help` | 返回指令列表 |

四条都过 = 装完了。想要语音、视频、记忆、主动消息，接着看 README 第 6–9 章。

## 第 10 步：让它别死在你手里（进阶）

- 想 7×24：README 第 11 章（Docker）
- 想防断线：README 第 12.2（NapCat WS 自愈）
- 想以后升级不翻车：README 第 12.5（升级流程，必看）

---

## 卡住了怎么办

| 现象 | 直接跳到 |
|---|---|
| 发消息没反应 | README 14 章 #5（NapCat WS 断了） |
| 发纯表情她装死 | #1 |
| 语音合成失败 | #15（两个源码补丁） |
| 语音里念出「旺柴」 | #14 |
| 插件市场装不上 | #17（代理） |
| 升级后什么都没了 | #20 + 12.5 节 |

**一句话原则**：所有"她好像不太对"，最后都能在日志里找到一句明确的错。
先看日志，再怀疑模型。
