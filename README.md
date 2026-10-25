# 🐋 大肥鱼 · 操作手册

> 把一只住在 QQ 里的鲸鱼娘，从零搭到 7×24 在线。
> **AstrBot + NapCat + DeepSeek + 阿里云百炼**，Windows 本机或云服务器都能跑。

这套东西是我自己一行行搭出来的，下面每一步都跑通过。凡是标 ⚠️ 的地方，都是我真实踩进去、
爬起来之后才写下的；第 14 章把 21 条坑压成了一张表，出问题先翻那张表。

---

## 0. 怎么用这本手册

| 你想干什么 | 看哪一章 | 大概耗时 |
|---|---|---|
| 先让她会打字聊天 | 1 → 2 | 40 分钟 |
| 让她会发表情、看得懂图 | 3 | 20 分钟 |
| 给她一个人格 | 4 | 5 分钟 |
| 让她会发语音条 | 6 | 半天（主要在等复刻） |
| 让她看得懂视频、听得见声音 | 7 | 30 分钟 |
| 让她记得住、有知识库 | 8 | 30 分钟 |
| 让她主动找你、有作息 | 9 | 20 分钟 |
| 7×24 挂云端 | 11 | 1 小时 |
| 出故障了 | 14 | — |

**需要准备：**

- 一台 Windows 10/11（本机跑）或一台云服务器（长期跑）
- **一个 QQ 小号**（强烈建议，主号有风控概率）
- DeepSeek API Key（对话主力，便宜）
- 阿里云百炼 API Key（看图 / 听写 / 说话，三件都靠它）
- 可选：Ollama（本地 bge-m3 嵌入，记忆检索用，免费且不外传）

---

## 1. 架构与端口

```
QQ 小号 ── NapCat（协议端）──┐
                            ├── WebSocket 6199
AstrBot（大脑：人格/插件/记忆）┘
   ├── DeepSeek API        ← 对话主力
   ├── 阿里云百炼           ← 眼睛/耳朵/嗓子
   │     ├─ qwen3-vl-plus          图片、视频画面转述
   │     ├─ qwen3-asr-flash        语音听写
   │     └─ qwen-audio-3.1-tts-flash  语音条（含自定义音色）
   └── Ollama bge-m3        ← 记忆与知识库的嵌入
```

| 端口 | 谁在用 | 说明 |
|---|---|---|
| 6185 | AstrBot 面板 | WebUI，配人格/提供商/插件 |
| 6099 | NapCat WebUI | 扫码登录、WS 配置、自愈 API |
| 6199 | OneBot v11 WS | AstrBot 的**反向** WS，NapCat 连进来 |
| 8009 | PhoneMCP | 手机控制（只绑 127.0.0.1） |
| 8010 | BrowserMCP | 浏览器任务（SSE） |
| 8012 | loopback ASR | 听"模拟器里正在播的声音"用的反向隧道 |

> 除 6185/6099 需要你自己开面板，其余一律**只监本机**，安全组/防火墙不要放行。

---

## 2. 先让文字跑通（第一关）

### 2.1 装 AstrBot（大脑）

- 推荐 **AstrBot Launcher**（图形化，自带隔离环境、托盘、开机自启）。
- 国内网络：进「高级 → 通用」，打开 **中国大陆一键加速**（走中科大镜像）。
- 本文基于 **AstrBot 4.29.3**。版本差异会影响插件与补丁，升级前先看第 12.5 节。

### 2.2 装 NapCat（QQ 协议端）

- Windows 下用 `NapCat.Shell.Windows.Node.zip`（自带 Node 运行时）。
- 启动脚本建议 `launcher-win10-user.bat`（免管理员）。
- 首次启动在 WebUI（`http://127.0.0.1:6099`）扫码登录**小号**。
- 本文基于 **NapCat 4.18.41**（发布包校验 SHA256）。

### 2.3 把两边接起来

在 NapCat WebUI 或配置文件 `config/onebot11_<QQ号>.json` 里，加一个 **websocket 客户端**：

```json
{
  "name": "astrbot",
  "url": "ws://127.0.0.1:6199/ws",
  "enable": true
}
```

AstrBot 侧：平台适配器选 **QQ(aiocqhttp)**，端口 **6199**。

### 2.4 配三个提供商

| 提供商 | 型号 | 填在哪里 |
|---|---|---|
| DeepSeek | `deepseek-chat` | 对话主力（`https://api.deepseek.com/v1`） |
| 百炼视觉 | `qwen3-vl-plus` | 「图片转述提供商」 |
| 百炼语音 | `qwen-audio-3.1-tts-flash` | TTS 提供商（见第 6 章） |
| Ollama | `bge-m3` | 嵌入提供商（`ollama pull bge-m3`） |

### 2.5 第一关验收

1. 手机给小号发"在吗" → 有文字回复
2. 发一张图 → 她能说出图里有什么
3. `/help` → 能返回指令列表

> 这三条不过，别往下走。后面所有功能都建在这条链路上。

---

## 3. 核心插件：face_convert（表情与媒体）

这是我为这个项目写的插件，做的是**出站整形 + 入站翻译**双通道。

### 3.1 安装

```
把 plugin/astrbot_plugin_face_convert/ 整个文件夹
放进 AstrBot 数据目录的 data/plugins/  →  重启
```

数据目录位置：Launcher 版在 `…/instances/<实例id>/core/data/`；手动部署版在 AstrBot 根目录 `data/`。

依赖：`dashscope`（语音/视频理解）、`imageio-ffmpeg`。首次用到某功能报缺包，按提示 `pip install`。

### 3.2 它到底做了什么

**出站（她说什么）**

| 处理 | 效果 |
|---|---|
| 中括号表情名 → 真表情段 | `[旺柴]` 变成真 QQ 表情（QQ 不渲染机器人发的文本表情码） |
| 草稿箱 | `（（ ））` 里的内容被撕掉——给她一个"自己咽回去"的出口 |
| 三道橡皮擦 | 嘴硬小尾巴 / meta 口癖句 / 表情冷却（可逐道关） |
| 标点归一 | 顿号后接「也/就/但/所以/或者」改逗号；「」统一成 “” |

**入站（她看到什么）**

| 输入 | 处理 |
|---|---|
| 纯表情消息 | 上游 `message_str` 是空串会被整条跳过 → 翻译成 `[旺柴]` 文本 |
| 图片 / 表情包 | 补一句"[对方发来一张图片]"，交给图片转述 |
| 语音 | NapCat 转 mp3 → qwen3-asr-flash 听写 → 文本进上下文 |
| 视频 | 本地下载 → ffmpeg 抽帧 + 抽音轨 → 分批看 + 分段听 |
| 身份标记 | 群里带 `[昵称(QQ号)]`，管理员标「主人」，访客标「朋友」；**对方看不到** |

### 3.3 配置项（`data/plugins/astrbot_plugin_face_convert/config.json`）

```json
{
  "max_media_mb": 80,
  "video_max_duration_s": 300,
  "video_max_frames": 16,
  "video_audio_chunk_s": 60,
  "video_timeout_s": 300,
  "vl_timeout_s": 60,
  "asr_timeout_s": 60,
  "max_concurrent_media": 1,
  "video_workers": 2,
  "media_queue_timeout_s": 10,
  "hedge_eraser": true,
  "face_cooldown_minutes": 5
}
```

⚠️ **旧 config.json 不会被自动改写**。如果你以前配过 `max_media_mb: 20` / `video_timeout_s: 150`，
这些**旧值仍然生效**——升级时要手工合并，否则你会以为默认值没生效。

边界：时长 1–300 秒、帧数 1–32、分段 10–60 秒、内部任务 1–2。越界会被钳到范围内。

### 3.4 规则回归测试

```bash
python tests/test_face_rules.py
python tests/test_video_processing.py   # 需要 aiohttp + ffmpeg
```

第二组会生成 3 / 5 / 5.5 分钟真实视频，验证结尾画面与音轨、静音短片、下载限额、部分失败、
取消清理。**模型响应用测试替身，不花钱、不连 QQ**——但合并后仍要用真实视频验一遍。

---

## 4. 人格：5 分钟

1. 打开面板 `http://localhost:6185` → 配置 → 人格 → 新建
2. 名称 `大肥鱼`
3. 系统提示词：把 `persona/大肥鱼-人格.md` 里 `---` 之后的**整段正文**粘进去
   （v2 起是单块提示词，不用拼接、不用粘标题和引用说明）
4. 保存，设为默认人格
5. 验证：发一句"在吗"，调子应该是"嘴硬 + 语气词"，不是客服腔

---

## 5. 课程记忆：教她，而不是灌她

「课程记忆」= 写进长期记忆的**自省小课**，用她自己的口吻（"我琢磨明白了…"）。
被召回时她当成"自己本来就懂的道理"，比系统提示词里的硬规矩自然得多。

### 路子 A（推荐）：当面教

1. 把 `persona/课程记忆-模板.md` 里的课**分几次**发给她（一次一条，别刷屏）
2. 每条发完，让她**用自己的话接一句**
3. 原理：livingmemory 存的是**她的那段回应**——那是"她亲口说过的话"

### 路子 B（进阶）：直接写库

> ⚠️ 先备份 `livingmemory.db`

库位置：`<数据目录>/plugin_data/astrbot_plugin_livingmemory/livingmemory.db`

```sql
INSERT INTO documents (doc_id, text, metadata, created_at, updated_at)
VALUES (
  lower(hex(randomblob(16))),
  '<课程正文>',
  '{"session_id":"qq:FriendMessage:<你的QQ号>","persona_id":"<人格id>","importance":0.8,"create_time":' || strftime('%s','now') || '}',
  datetime('now'), datetime('now')
);
```

保存后重启。直写库会绕过插件自动索引，召回效果随版本而异——稳一点走路子 A。

**验证方式**：过一阵聊到相关话题，看她自然带不带出来。
**别用"背一遍给我听"考她**——那会把课变成背书。

---

## 6. 语音：让她开口

### 6.1 录素材

`assets/voice-demo/` 里的是**成品演示**，不能当复刻素材。复刻要"人声原汤"：

- 10–20 秒单条连续说话
- 无 BGM、无混响、安静房间
- 离手机约 20 cm，采样率 ≥ 24 kHz

### 6.2 做复刻

百炼控制台 →「体验中心 → 语音模型 → 音色复刻」→ 上传 → 等完成 → 复制 **voice_id**
（形如 `qwen-audio-3.1-tts-flash-bailian-<id>`）

### 6.3 接到 AstrBot

「配置 → 提供商」新建，类型 **DashScope 语音（dashscope_tts）**：

| 键 | 值 |
|---|---|
| `api_key` | 百炼 Key |
| `model` | `qwen-audio-3.1-tts-flash` |
| `dashscope_tts_voice` | 上一步的 voice_id |

然后在 TTS 设置里把它设为默认（`provider_tts_settings.provider_id`）。

> ⚠️ **必打两个源码补丁**（见第 14 章 #15）：不打的话，设成 `qwen-audio-*` 会直接合成失败
> （url error），语速/音高也不生效。**升级 AstrBot 会覆盖补丁，要重打。**

### 6.4 语音行为参数（`provider_tts_settings`）

| 键 | 建议值 | 说明 |
|---|---|---|
| `enable` | true | 总开关 |
| `provider_id` | 你的 dashscope_tts | — |
| `dual_output` | true | true=文字+语音双发；false=只发语音条 |
| `trigger_probability` | ≈0.35 | 每条回复发语音的概率，太高会变复读怪 |

### 6.5 调音配方（打完补丁后，provider 条目里加）

```json
"dashscope_instruction": "",
"dashscope_speech_rate": 1.04,
"dashscope_pitch_rate": 1.0
```

即"零指令 + 语速 1.04 + 音高 1.0"。

**为什么指令留空**：给克隆音色加"撒娇 / 活泼"这类指令，会把**素材源的口音一起放大**——
这是我试了 8 个变体才认下的结论（#10）。

### 6.6 会话级开关

| 指令 | 作用 |
|---|---|
| `/语音开` | 打开当前会话语音条 |
| `/语音关` | 关闭（文字照常） |
| `/语音状态` | 查状态 |

会话级生效、重启保留。

**验证**：私聊两句，按概率收到语音条；语音里**不该念出"旺柴"**（念了 = 缺第三个补丁，#14）。

---

## 7. 视觉与听觉

### 7.1 图片

图片转述提供商填 `qwen3-vl-plus`。她看到的是"转述后的描述"，不是原图。

### 7.2 视频（插件 v1.2.0 起默认 3–5 分钟）

| 项目 | 默认行为 |
|---|---|
| 范围 | 最多前 300 秒，更长会明确注明后续未处理 |
| 画面 | 全程均匀取最多 16 帧（含开头与接近结尾），每 4 帧带时间戳一起理解 |
| 音频 | 每 60 秒一段 → 16 kHz 单声道 WAV，逐段转写并保留时间范围 |
| 文件 | 下载与本地共享文件均限 80 MiB，流式写盘 |
| 并发 | 同时 1 条媒体；视频内部最多 2 个任务 |
| 等待 | 排队最多 10 秒；拿到空位后整体最多 300 秒 |
| 失败 | 单段失败继续其他段；总超时返回已完成内容；取消后回收 ffmpeg 并清理临时文件 |

要说清楚：16 帧覆盖的是**整个时间范围**，不等于逐帧看完整片。快速动作、一闪而过的字幕、
只出现一瞬的物体都可能漏。音频在切段边界也可能漏词；时间戳是片段范围，不是逐字对齐。

成本：默认 5 分钟视频最多产生 4 次视觉请求 + 5 次 ASR 请求。**300 秒是等待上限，不是响应承诺。**

### 7.3 语音听写（ASR）的正确姿势

⚠️ DashScope 兼容模式**没有** `/audio/transcriptions`（404），AstrBot 原生 whisper_api 路线不通。
正确调用：

```python
MultiModalConversation.call(
    model="qwen3-asr-flash",
    messages=[{"content": [{"audio": "file:///本地路径"}]}],
)
```

### 7.4 听见"模拟器里正在播的声音"

她陪你看 B 站时听不到外放？用 Windows **loopback 录音** + 反向隧道：

```
本地录音 → 127.0.0.1:8012 ── ssh -L 8012:127.0.0.1:8012 ──→ 云端 ASR
```

---

## 8. 记忆与知识库

### 8.1 长期记忆

- 插件：`livingmemory`（社区）
- 嵌入：`bge-m3`，`ollama pull bge-m3` 本地跑，免费且不外传
- **作用域设为 `session`**：每个私聊、每个群各一册记忆，互不串账

⚠️ 记忆反思会**写错事实**，还会把错的当真事反哺（#16）。症状是"关心变念经"——
她会反复追问一件你早就报备过的事。翻记忆库能看到当天自动生成的日记把事实记反了。

### 8.2 知识库

把《功能手册》《热梗词典》导入 AstrBot 知识库，嵌入同样用 bge-m3。
`docs/知识库-热梗词典示例.md` 是现成可导入的样例。

效果：聊天里她"现查现答"，而不是把一堆说明塞进人格。

---

## 9. 主动与定时

### 9.1 proactive_chat 配方

| 项 | 值 |
|---|---|
| 私聊 `enable` | true |
| UMO 列表 | 只放需要的会话，如 `qq:FriendMessage:<你的QQ>`（私聊发 `/sid` 拿） |
| 上下文来源 | `conversation_history` |
| 间隔 | 最小 120 / 最大 240 分钟 |
| 最大未回复 | 2 次（连发两条没回才暂停，等你再开口恢复） |
| 免打扰 | `23-8`（支持跨午夜写法） |

⚠️ 定时任务 `misfire_grace_time` 默认 **60 秒**，迟到就**静默丢弃**。改到 3600（#12）。

### 9.2 未来任务配方（照抄即可，目标会话=私聊，人格选她）

| 服务 | 时间 | 任务说明 |
|---|---|---|
| 🌙 催睡觉 | 每晚 23:30 | 现在是晚上 23:30 左右。请用平常聊天的语气催主人早点睡觉：嘴上嫌弃他「又熬夜！」，心里舍不得、想多陪一会儿；一两句话就好，然后用发消息工具发给主人。 |
| ☀️ 叫起床 | 每天 07:00 | 现在是早上 7 点。请叫他起床：元气满满的早安、嫌弃他赖床，催他别磨蹭；一两句话就好，语气像平时的她，然后用发消息工具发给主人。 |
| 🎬 逛 B 站 | 每天 20:30 | 配合手机/浏览器能力，自己上网找话题 |

### 9.3 schedule_awareness 插件

她早期总说"我没有日程"——因为定时任务是平台层的，她看不见。
`astrbot_plugin_schedule_awareness` 每轮把她名下真实存在的 `cron_jobs` **只读注入**系统提示词，
按会话隔离。装进 `data/plugins/`，重启即生效。

### 9.4 联网搜索

面板 → 配置文件 → AI → 能力 → 网页搜索：启用，提供商 `anysearch`，**Key 留空**用匿名每日额度。
建议同时开"显示来源引用"。

对应键：

```yaml
provider_settings:
  web_search: true
  websearch_provider: anysearch
  websearch_anysearch_key: []
```

⚠️ 验收别听她说"我查过啦"——去会话记录里看有没有 `web_search_anysearch` 的 `tool_calls`
和工具返回的真实链接。

**主动消息也想联网**：proactive_chat 默认直调 `text_chat()`，手里没有工具。用
`deploy/patches/proactive_chat/` 的两个补丁覆盖同名文件并重启。验收：
`docker logs astrbot | grep '工具 web_search_anysearch 执行完成'`。

---

## 10. 生态插件与指令

| 插件 | 玩法 | 注意 |
|---|---|---|
| `parser` 链接解析 | 丢 B站/抖音/小红书链接，她接着聊 | — |
| `music` 点歌 | "我想听xx" → 发歌/语音条 | — |
| `pokepro` 戳一戳 | 被戳有反应 | **关掉它默认的定时戳任务** |
| `stealer` 偷表情包 | 自动收集分类，按情绪发 | 需配视觉模型 |
| `memelite` 表情包生成 | 现做沙雕表情 | — |
| `omnidraw` 生图 | `/画`、`/自拍` | 需配生图 API |

**指令速查**（私聊直接发；群聊 @她 或以 `/` 开头）

| 类 | 指令 |
|---|---|
| 语音 | `/语音开` `/语音关` `/语音状态` |
| 画图 | `/画 提示词` `/自拍 场景` `/视频 提示词` |
| 点歌 | `/点歌 歌名` `/查歌词` |
| 表情 | `/贴表情` `/meme列表` `/摸头 @某人` |
| 互动 | 戳一戳她 / `/戳` |
| 内置 | `/help` `/reset` `/sid` `/provider` |

> 大部分需求用自然语言说就行（"给我画个…"、"来个自拍"），她会自己调能力。
> 标 👑 的管理指令（`/人设`、`/切换模型`、`/切换链路`）仅管理员可用。

---

## 11. 云上安家（7×24）

本机跑的硬伤：你一关机她就没了。`deploy/` 里有 Docker 一键编排。

```bash
cd deploy
docker compose up -d
```

要点：

| 事项 | 做法 |
|---|---|
| 数据持久化 | 挂载 `astrbot/data/`（人格、插件、记忆库都在里面） |
| 宿主回环 | 容器访问不到宿主 `127.0.0.1`，用 `172.18.0.1` 或写 proxy 转发 |
| PhoneMCP | 容器侧用 `phone_mcp_proxy.py` 监听 `172.18.0.1:8009` → 转发 `127.0.0.1:8009` |
| BrowserMCP | SSE 8010，反向隧道接入 |
| 备份 | 见 12.4，`livingmemory.db` 单独算一份 |

`data/mcp_server.json` 示例：

```json
{"phone-mcp": {"url": "http://172.18.0.1:8009/Phone", "transport": "sse", "active": true}}
```

重启后日志应出现 `Connected to MCP server phone-mcp`。
验收：`list_devices`、`get_ui_elements`、`get_screenshot` 能拿到设备、元素、真实截图。

---

## 12. 运维

### 12.1 日常体检

| 检查 | 怎么看 |
|---|---|
| 进程活着 | `docker ps` 或任务管理器 |
| WS 连着 | AstrBot 日志/platform 状态，NapCat WebUI 连接列表 |
| 能收发 | 手机发一句"在吗" |
| 记忆在写 | 看 `livingmemory.db` 的 mtime |
| 定时没断 | 面板「未来任务」列表 |

### 12.2 连接自愈（NapCat 断线不自愈）

NapCat 的 WS 在 AstrBot 重启后**会悄悄断掉且不自动重连**；直接重启 NapCat 又会丢登录态要扫码。

解法：调 **NapCat WebUI API** 把 websocket 客户端"关一下再开"——2 秒重连，免扫码。
写成脚本挂计划任务或常驻进程定时巡检即可（原理见 #5）。

### 12.3 Windows 专属两条

```bash
# 合盖不睡（交流/直流都设）
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
```

⚠️ Git Bash 里 `/xxx` 会被当路径，先 `export MSYS_NO_PATHCONV=1`（#13）。

### 12.4 备份

要备份的就三样：

1. `astrbot/data/`（人格、插件、配置）
2. `plugin_data/astrbot_plugin_livingmemory/livingmemory.db`（记忆，最值钱）
3. `napcat/config/`（协议端配置）

⚠️ 备份/启动脚本"假成功"是踩过的坑（v1.8.1 修复）——**备份完要验文件大小和可恢复性**。

### 12.5 升级流程（最容易翻车的一步）

⚠️ 大版本升级会**整体替换 core、丢依赖、覆盖补丁**（#20）。按这个顺序：

```
1. 备份（12.4）
2. 记录当前版本号
3. 升级
4. 重打补丁：qwen-audio TTS 两个、proactive_chat 两个、PhoneMCP UTF-8 一个
5. 重装依赖：dashscope、imageio-ffmpeg、aiohttp
6. 核对 config.json 有没有被重置（尤其 face_convert 的媒体参数）
7. 跑 13 章验收清单
```

---

## 13. 验收清单（每次动完配置都跑一遍）

1. 发"在吗" → 有文字回复，含真表情
2. 发一张图 → 她描述得出来
3. 发一条语音 → 她复述得出来
4. 发个纯表情 → 她有反应（不是装死）
5. 发一个短句让她发语音条 → 语音里没有"旺柴"
6. 聊十几轮 → 提"上次说的那事"，看记忆召回
7. 群里 @ 她 → 她会应；不 @ 时安静旁观
8. 群里换个号说话 → 她分得清是谁（标记只进她上下文）
9. 等 2–4 小时不聊 → 可能主动冒泡（间隔 120–240 分钟随机）
10. 面板「未来任务」→ 23:30 / 07:00 两条还在

---

## 14. 故障速查（21 条浓缩版）

| # | 症状 | 根因 | 处置 |
|---|---|---|---|
| 1 | 发纯表情她装死，日志无报错 | 纯表情消息 `message_str` 是空串，被上游当空消息跳过 | 插件把表情翻译成 `[旺柴]` 文本 |
| 2 | 视频处理静默失败，`ffmpeg rc=-2` | NapCat 给的 `file` 只是**光杆文件名**，无路径无 URL | 按 NapCat 共享目录拼出真实路径 |
| 3 | 某张脸发送报 `retcode 1200 无法解析` | 社区快照与 NapCat 运行时**两套编号体系** | 只用 NapCat 运行时表里的 id |
| 4 | `[旺柴]` 查不到 | 同一张脸手机端叫"旺柴"、NapCat 内部叫"**汪汪**"(277) | 按内部名建映射 |
| 5 | AstrBot 重启后发消息没反应 | NapCat WS 断了**不自愈**，重启又要扫码 | WebUI API 关一下再开，2 秒重连 |
| 6 | 连着几条都用同一句开头 | LLM 会**模仿自己最近的发言**，系统提示打不过聊天记录 | 清上下文 / 换开场，别指望人格硬压 |
| 7 | 灌进去的规矩三句就忘 | 被动灌 ≠ 她的认知 | 走「课程记忆」，让她自己说出来 |
| 8 | 橡皮擦误删 / 漏删 | 链式改写时门槛没算全所有计数器；关键词太宽 | 门槛算全部计数器；关键词收窄，宁漏不错杀 |
| 9 | ASR 404 | DashScope 兼容模式**没有** `/audio/transcriptions` | 用 `MultiModalConversation` + `qwen3-asr-flash` |
| 10 | 克隆音色带口音 | 加"撒娇/活泼"指令会把素材源口音一起放大 | 指令留空，只调语速音高 |
| 11 | 服务端取 QQ CDN 链接不稳 | 服务端跨网取媒体易失败 | **本机**先下载再交给模型 |
| 12 | 主动消息不发或乱发 | `misfire_grace_time=60`，迟到即丢 | 改 3600；接受随机排班 |
| 13 | powercfg 报错 / `\N` 转义 | Git Bash 路径转换；docstring 里的反斜杠 | `MSYS_NO_PATHCONV=1`；docstring 用 `r"""` |
| 14 | 语音把"旺柴"念出来 | TTS 在表情转换**之前**跑，合成器不认识方括号 | 合成前过滤表情标记；纯标点不合成 |
| 15 | 设了 qwen-audio 直接合成失败 | AstrBot 把 `qwen*tts*` 路由到 HTTP 多模态接口，而 qwen-audio 走的是另一条 | 打两个源码补丁（url + 语速音高） |
| 16 | 她反复追问已确认的事 | 记忆反思**写错事实**并反哺 | 翻记忆库改正；别让反思直接落库 |
| 17 | 插件市场装不上 | GitHub 被卡 | 安装接口传 `proxy` 前缀 |
| 18 | WebUI 报 Not Login | NapCat "半重启"，认证状态坏了 | 按内部半重启流程恢复，别急着重新扫码 |
| 19 | 第三方生图没有 `/images/edits` | 服务不提供改图接口 | 退回文生图 + 提示词约束；参考图路径要过校验 |
| 20 | 升级后功能全没了 | core 被替换、依赖丢失、补丁被覆盖 | 按 12.5 流程走 |
| 21 | 她开始复述不该复述的东西 | 注入残渣 × 格式回声，被带出"程序壳" | 清会话、收紧入站标记、加防注入约束 |

---

## 15. 安全红线

- **访问控制白名单**：只放行你自己的会话（`qq:FriendMessage:<你的QQ>`，UMO 用 `/sid` 拿）
- 加好友必须**你手动通过**——第一道门永远在你手里
- 主动消息必开**免打扰**（`23-8`）
- **ADB / PhoneMCP / BrowserMCP 不开公网端口**，安全组不要放行 8009/8010
- 面板密码、WebUI token **只在本机看，不要截图公开**
- 用**小号**；小号手机端偶尔挂着活跃，降低风控概率

---

## 16. 目录结构

```
plugin/astrbot_plugin_face_convert/      核心插件（直接可装）
plugin/astrbot_plugin_schedule_awareness/ 定时任务实时注入
persona/大肥鱼-人格.md                    人格提示词
persona/课程记忆-模板.md                  "教她"的模板
docs/部署指南.md                          路线图与关键决策
docs/导入指南.md                          人格 / 课程记忆 / 音色 手把手
docs/指令手册.md                          指令速查
docs/视频识别.md                          视频参数与边界
docs/知识库笔记.md                        知识库接线
docs/知识库-热梗词典示例.md                现成热梗词典
docs/踩坑合集.md                          ⭐ 21 条坑与解法原文
docs/构建记.md                            这东西是怎么一步步长出来的
deploy/                                  云上安家（Compose / 备份 / 嵌入切换）
deploy/phone_mcp/                        模拟器接入
deploy/ops_mcp/                          云端运维 MCP
deploy/browser_use/                      只读浏览器任务
tests/                                   回归测试
assets/avatars/                          头像素材（含授权署名）
assets/voice-demo/                       音色样本与复刻链路说明
```

---

## 附：版本演进

| 日期 | 版本 | 关键变化 |
|---|---|---|
| 10-14 | v1.0 / v1.1 | 首版；进群、认人、记忆隔离 |
| 10-15 | v1.2 → v1.2.8 | 生态篇、连接韧性、反注入、知识库、生图、定时配方 |
| 10-17 | v1.3.0 | 云上安家（Docker） |
| 10-18 | v1.3.x | 视频 3–5 分钟、备份自带 WS 自愈 |
| 10-19 | v1.4.0–1.4.3 | 人格 v2 / v2.1、主动消息低频配方、联网搜索 |
| 10-20 | v1.4.4–1.4.8 | 手机控制、快速登录、逛 B 站、Browser Use、叫起床 |
| 10-21 | v1.5.x–1.7.0 | 标点归一、听模拟器原声、日程自知 |
| 10-23 | v1.8.0–1.8.2 | 排障变 MCP、备份不再假成功、自愈收敛 |

---

> **关于角色**：大肥鱼是 DeepSeek 蓝鲸 logo 的**社区二创形象**（"你这只吃白饭的蓝色大肥鱼"梗），
> 非官方。角色设定规范参考 [YunYueSama/codex-deepseek-pet](https://github.com/YunYueSama/codex-deepseek-pet)。
>
> **依赖生态**：[AstrBot](https://github.com/AstrBotDevs/AstrBot) ·
> [NapCat](https://github.com/NapNeko/NapCatQQ) ·
> [livingmemory](https://github.com/lxfight-s-Astrbot-Plugins/astrbot_plugin_livingmemory) ·
> [proactive_chat](https://github.com/Pancakes-Labs/astrbot_plugin_proactive_chat)
>
> **License**：MIT。人格文本与插件代码可自由使用，转载注明出处即可。
>
> 最后更新：2026-10-25 · 对应 AstrBot 4.29.3 / NapCat 4.18.41
