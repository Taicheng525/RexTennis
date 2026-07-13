# RexTennis 🎾

iPhone 网球比分**语音播报** App：连上蓝牙耳机后，每得一分自动用系统语音播报当前比分，打球时无需看手机。**完全离线**，无任何网络依赖。

- 平台：iOS 17+（面向 iPhone 13 Pro Max）
- 技术：SwiftUI + AVFoundation（`AVSpeechSynthesizer` 离线 TTS，`AVAudioSession(.playback)` 自动路由蓝牙）
- 语言：中文 / English 可切换（记住上次选择）；英文播报用**英式口音（en-GB）**，贴近温网裁判
- 裁判声音：**女裁判 / 男裁判** 可选（按性别+音质从系统人声中自动挑选最佳）
- 队名：赛前可输入双方队名（记住上次输入）
- 设计：简约高级 dark 风（草地绿 + 网球黄绿 + 奶白，拟物网球元素）

## 赛制规则

- **一盘定胜负**，赛前可选 **4 局制 / 6 局制**。
- 每局无广告（金球）：先到 4 分胜局；**40-40 平分后，下一分直接定局**。
- 胜盘：局数达到目标且**净胜 2 局**；否则到 **N-N 打抢七**（4 局制 4-4，6 局制 6-6）。
- 抢七：先到 **7 分且净胜 2 分**；发球 1-2-2-2 轮换，每 6 分换边。
- 追踪发球方：**报分只报数字、发球方分数永远在前**（专业裁判风格：中文「四十比三十」「十五平」，英文 "forty thirty" / "fifteen all"，0 读 love / 零）；队名只出现在「拿下这一局 / 该谁发球 / 胜盘」播报中。
- 换边：**只做界面文字提醒（不语音）**；快速连续得分时**只播报最新比分**（打断上一条，不排队）。
- 记分：两个大按钮「我方 +1 / 对方 +1」，另有「撤销」「再报一次」。

## 构建与运行

依赖 [XcodeGen](https://github.com/yonyz/XcodeGen)（`brew install xcodegen`）。`.xcodeproj` 不入库，需先生成：

```bash
cd RexTennis
xcodegen generate          # 生成 RexTennis.xcodeproj
open RexTennis.xcodeproj    # 用 Xcode 打开
```

### 模拟器

```bash
xcodebuild -project RexTennis.xcodeproj -scheme RexTennis \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

### 单元测试（计分引擎）

```bash
xcodebuild -project RexTennis.xcodeproj -scheme RexTennis \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

### 真机 + 蓝牙耳机（推荐的实际验证方式）

1. Xcode 打开工程，选 **RexTennis** target → Signing & Capabilities → 勾选 *Automatically manage signing*，选择你自己的 Apple ID Team（`PRODUCT_BUNDLE_IDENTIFIER` 如冲突可改）。
2. 连接 iPhone 13 Pro Max，选它为运行目标，Run。
3. iPhone 连接 AirPods 等蓝牙耳机。
4. 开一场比赛，点几下加分按钮，确认播报**从蓝牙耳机**发出；锁屏后仍能继续播报（已声明后台音频模式）。

## 目录结构

```
Sources/
  RexTennisApp.swift          App 入口
  Models/                     Side / MatchConfig / MatchState / MatchEvent / ScoreEngine（纯逻辑）
  Audio/                      Announcer（TTS）/ AnnouncementBuilder（中英文案）
  ViewModels/                 AppModel / MatchViewModel（撤销快照）/ SettingsStore
  Views/                      ContentView / SetupView / MatchView
Tests/
  ScoreEngineTests.swift      计分引擎单测
```

计分逻辑集中在 `Sources/Models/ScoreEngine.swift`，为纯值类型逻辑、无 UI/音频依赖，便于单测与后续扩展（如多盘、比赛历史）。
