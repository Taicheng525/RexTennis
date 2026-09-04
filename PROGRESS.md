# RexTennis 进展记录

按日期倒序。记「做了什么、为什么这么决定、下一步」，代码细节看 git log。

## 2026-09-05 — TestFlight build 2

### 做了什么
- **TestFlight 已跑通**：build 1 上传成功；建了内部组（自己 + 1 位朋友，零审核）和外部组「网球群管理员」（公开链接，等 Beta 审核）。踩坑记录：
  - Organizer 上传报 "No Accounts"：Xcode → Settings → Accounts 里要登录付费账号 425286520@qq.com。
  - 左侧没有「外部测试」：Apple 规定必须先建一个内部组，外部组的 + 才出现。
  - 内部测试员状态一直「已邀请」：要在手机上点邀请邮件里的 View in TestFlight 才算接受；TestFlight 用的是「媒体与购买项目」的 Apple ID，可能和 iCloud 账号不同。
  - 邀请朋友进后台时关掉「访问所有 App」只勾 Rex Tennis，其他 app（HomeGuard）对他不可见。
- **人声教程页重做**：固定推荐 4 个人声（英文 Kate/Jamie，中文 丽丽/汉，不再按性别切换）、面包屑路径、一屏放完；加了「朗读语言切方言 → 裁判说方言」彩蛋提示。
- **方言问题**：iOS 18+ 的「朗读语言」是系统级设置，app 无法覆盖/检测。另加了标准普通话人声名单优先规则，防止只按音质挑到方言人声。
- build 号 1 → 2。

### 下一步
- 等外部组 Beta 审核通过后把公开链接发群。
- 收集反馈；付费方案仍推后。

## 2026-09-04 — TestFlight 前的最后一轮

### 目标
把 app 通过 TestFlight 发给朋友试用。付费/内购（IAP）**尚未开始做**，先免费发测试版收反馈。

### 做了什么
**1. 音效 / 报分延迟**（用户反馈：点欢呼、报分都有可感知的延时）
- 新增 `AudioSessionManager`：音频会话**只配置一次**（之前语音和音效各自反复 `setCategory`，每次都触发路由重配）；比赛期间用一条**静音循环保活**，防止蓝牙耳机几秒无声后断流、下次出声要重新拉起链路。
- `Announcer` 重写渲染管线：**预渲染**——每得一分后把「下一分我方得 / 对方得」两种播报、当前比分、4 句裁判喊话提前烘好；渲染串行化、同文案去重；渲染在点击瞬间开始，debounce 只推迟播放（160ms → 100ms）；报分前置停顿 80ms → 40ms。
- 蓝牙编解码本身约 150–250ms 延迟是硬件层面的，任何 app 都消不掉。

**2. 系统人声未安装的处理**
- 核实：iOS **没有任何 API 能让 app 代替用户下载系统人声**，也不允许直接跳到「辅助功能」设置页（私有 URL 会被拒）。
- 设置页「裁判声音」下方：检测到缺高音质人声/所选性别人声时显示提示 +「怎么安装人声」5 步教程（`VoiceInstallGuideView`），从设置回到 app 自动重新检测。
- 在真机上读出已安装人声列表后，教程按语言×性别只推荐**一个**名字，并让 `pickVoice` 在同音质下优先挑这一个：

  | | 女声 | 男声 |
  |---|---|---|
  | 中文 | 丽丽 Lili（高级） | 汉 Han（高级） |
  | 英文 | Kate（增强） | Jamie（高级） |

**3. 内置预录人声方案（做了，又搁置）**
- 曾实现「用户没装增强人声 → 用随包的高质量预录片段（不带人名）」的完整链路：`AnnouncementBuilder.Phrase.clipID`、`VoiceClips`、`tools/gen_voices.py`（支持 OpenAI / ElevenLabs / Azure / macOS say），每语言×性别 330 条片段，有单测。
- 搁置原因：所有能商用的音频来源都要注册/充值（Azure 免费档 F0 不含商用授权；OpenAI API 与 ChatGPT 会员是两回事、要预充 $5），本机开源模型（Qwen3-TTS / Kokoro）也嫌麻烦。用户决定**先只引导安装 iOS 增强人声**。
- 代码保留、`Resources/Voices` 为空 → 运行时自动全走系统 TTS。以后想启用只需把片段放进目录。
- ⚠️ macOS `say` 生成的音频 Apple 许可**禁止再分发**，绝不能打包。

**4. 上架准备**
- `project.yml` 加 `ITSAppUsesNonExemptEncryption: false`，每次上传不再弹「出口合规」问卷。
- Release 归档验证通过；签名 Team `N7W8Q9AW3F`（付费个人账号）。
- 手机上旧 team 签名的 app 需先删除才能装新签名的版本（会丢本地名单）。

### 讨论中定下的原则
- **播报延迟不能增加**：任何新声源都必须复用预取 + 缓存 + 同一套 PA 烘焙。
- **一场比赛只有一把嗓子**：不混用系统 TTS 与其他声源。
- 付费功能推后，先发 TestFlight。

### 下一步
1. Archive → 上传 App Store Connect → TestFlight 建测试组、加朋友邮箱（步骤见下）。
2. 收集朋友反馈。
3. 之后再做：付费方案（StoreKit 2 + paywall）、内置人声（如决定做）。

### TestFlight 操作步骤（备忘）
1. Xcode 打开工程 → 顶部设备选 **Any iOS Device (arm64)** → 菜单 Product → **Archive**。
2. 归档完自动弹 Organizer → 选中刚才的归档 → **Distribute App** → **App Store Connect** → Upload → 一路 Next（自动签名会顺手建 Distribution 证书）→ Upload。
3. 等 5–15 分钟收到「build 已处理完成」邮件。
4. appstoreconnect.apple.com → 我的 App → Rex Tennis → **TestFlight** 标签。
5. 外部测试（推荐给朋友）：左侧「外部测试」旁 + 新建组 → 添加测试员（填朋友邮箱）→ 选 build → 填一段「测试信息」→ 提交 Beta 审核（首个 build 通常 1 天内过）→ 过审后朋友收到邮件。
6. 内部测试（立刻可用、但要先把人加进你的开发者账号）：「用户和访问」里邀请对方 Apple ID 并给 Developer 角色 → TestFlight 左侧「内部测试」+ 建组勾选自动分发 → 添加测试员。
7. 朋友：装 TestFlight app → 点邮件里的链接 → 安装。
