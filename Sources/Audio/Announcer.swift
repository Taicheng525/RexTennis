import AVFoundation

/// 离线语音播报：TTS 渲染后**离线烘焙**现场 PA 效果（短延迟回声 + 球场混响），
/// 模拟裁判透过场内广播报分的空间感；运行时用 AVAudioPlayer 播放成品，
/// 无实时引擎、无路由竞争崩溃。音频自动路由到已连接的蓝牙耳机。
///
/// - **只报最新**：连续得分 debounce 合并，只播报最后一条。
/// - **单一裁判人声**：整场只用「所选语言 + 所选性别」这一把嗓子，中途切换即时生效。
/// - **文案缓存**：同一比分文案只烘焙一次，之后即点即播。
/// - MainActor 串行化状态访问。
@MainActor
final class Announcer {

    private var sessionConfigured = false
    private var pendingText: String?
    private var pendingEmphatic = false
    private var pendingWork: DispatchWorkItem?
    private var playTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var cache: [String: Data] = [:]

    /// 合并快速连点的间隔。
    private let debounceDelay: TimeInterval = 0.16

    var language: AnnounceLanguage = .chinese
    var umpire: UmpireVoice = .female

    // MARK: - 对外接口

    /// 朗读一句文案。连续调用只会播报最后一条。
    func speak(_ text: String, emphatic: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureSessionIfNeeded()

        pendingText = trimmed
        pendingEmphatic = emphatic
        pendingWork?.cancel()
        playTask?.cancel()
        player?.stop()   // 打断上一条（连点场景）

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in self?.flushPending() }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: work)
    }

    /// 立即停止并清空待播（撤销、新比赛清场，不发声）。
    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        pendingText = nil
        playTask?.cancel()
        player?.stop()
    }

    // MARK: - 渲染与播放

    private func flushPending() {
        guard let text = pendingText else { return }
        pendingText = nil
        let emphatic = pendingEmphatic
        pendingEmphatic = false

        playTask = Task { [weak self] in
            guard let self else { return }
            guard let voice = self.matchVoice() else { return }
            // 英文播报里若出现中文（队名），队名那几个字用中文嗓念出，其余保持英音
            let needsMix = self.language != .chinese && text.containsCJKText
            let cjkVoice = needsMix ? Self.pickVoice(languageCode: "zh-CN", umpire: self.umpire) : nil
            let key = "\(text)|\(voice.identifier)|\(cjkVoice?.identifier ?? "-")|\(emphatic)"
            var data = self.cache[key]
            if data == nil {
                // 裁判喊话(emphatic)放慢语速，让 "Out" 这类短词收音完整、更有喊话的分量；
                // 常规报分保持接近自然的语速。改音高会让人声失真，故只改语速。
                let rate = AVSpeechUtteranceDefaultSpeechRate * (emphatic ? 0.80 : 0.94)
                let buffer: AVAudioPCMBuffer?
                if needsMix, let cjkVoice {
                    buffer = await TTSRender.renderMixed(text: text, primaryVoice: voice,
                                                         cjkVoice: cjkVoice, rate: rate, pitch: 1.0)
                } else {
                    buffer = await TTSRender.render(text: text, voice: voice, rate: rate, pitch: 1.0)
                }
                guard let buffer else { return }
                // 用文案的稳定 hash 做背景起点偏移——不同比分的底噪从不同位置取，不再千篇一律
                let seed = text.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
                data = await OfflineFX.bakeStadiumPAAsync(buffer, emphatic: emphatic, seed: seed)
                if data == nil {   // 偶发失败：稍候重试一次
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    data = await OfflineFX.bakeStadiumPAAsync(buffer, emphatic: emphatic, seed: seed)
                }
                if let data {
                    if self.cache.count > 80 { self.cache.removeAll() }   // 粗粒度限容
                    self.cache[key] = data
                }
            }
            guard let data, !Task.isCancelled else { return }
            self.player?.stop()
            self.player = try? AVAudioPlayer(data: data)
            self.player?.play()
        }
    }

    /// 配置播放会话：`.playback` 默认走蓝牙；`.duckOthers` 播报时压低其他音乐。
    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            sessionConfigured = true
        } catch {
            sessionConfigured = false
        }
    }

    // MARK: - 人声挑选

    /// 整场唯一的裁判人声：完全跟随所选播报语言 + 性别，中途切换即时生效。
    /// 不按每句文本切换语言——那会造成「第三个声音」在场上出现。
    private func matchVoice() -> AVSpeechSynthesisVoice? {
        Self.pickVoice(languageCode: language.voiceCode, umpire: umpire)
    }

    /// 常见系统人声的姓名→性别对照（很多人声的 gender 字段是「未指定」，
    /// 只按字段过滤会漏掉真实存在的男/女声，导致切换无效）。
    nonisolated private static let maleNameHints = [
        "daniel", "arthur", "aaron", "fred", "gordon", "rishi", "alex",
        "oliver", "eddy", "reed", "rocko", "binbin", "禾"
    ]
    nonisolated private static let femaleNameHints = [
        "tingting", "婷", "yushu", "语舒", "yue", "meijia", "sinji", "shasha", "lili",
        "kate", "serena", "martha", "stephanie", "susan", "samantha", "karen",
        "moira", "tessa", "fiona", "ava", "allison", "nora", "zoe", "shelley",
        "sandy", "flo", "kathy", "grandma", "nicky", "vicki", "princess"
    ]

    /// 推断人声性别：优先 gender 字段，未指定则按姓名对照猜。
    nonisolated static func inferredGender(_ voice: AVSpeechSynthesisVoice) -> AVSpeechSynthesisVoiceGender {
        if voice.gender != .unspecified { return voice.gender }
        let n = voice.name.lowercased()
        if maleNameHints.contains(where: { n.contains($0) }) { return .male }
        if femaleNameHints.contains(where: { n.contains($0) }) { return .female }
        return .unspecified
    }

    /// 指定语言下所选性别的人声是否存在（用于界面提示）。
    nonisolated static func voiceAvailable(gender: UmpireVoice, languageCode: String) -> Bool {
        let prefix = String(languageCode.prefix(2))
        let wanted: AVSpeechSynthesisVoiceGender = gender == .female ? .female : .male
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(prefix) && inferredGender($0) == wanted
        }
    }

    /// 从系统人声中挑选：先按（推断）性别过滤（无匹配则退回全部），再取音质最高的。
    /// **完全确定性**：音质、区域匹配相同时用 identifier 兜底排序，
    /// 保证同一设置每次都挑到同一把嗓子（否则男声会时好时坏、忽男忽女）。
    nonisolated static func pickVoice(languageCode: String, umpire: UmpireVoice) -> AVSpeechSynthesisVoice? {
        let prefix = String(languageCode.prefix(2))
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == languageCode || $0.language.hasPrefix(prefix) }
        guard !all.isEmpty else { return AVSpeechSynthesisVoice(language: languageCode) }

        let wanted: AVSpeechSynthesisVoiceGender = umpire == .female ? .female : .male
        let genderMatched = all.filter { inferredGender($0) == wanted }
        let pool = genderMatched.isEmpty ? all : genderMatched

        func rank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
            switch q {
            case .premium: return 3
            case .enhanced: return 2
            default: return 1
            }
        }
        // 优先级：音质高 > 精确区域匹配（zh-CN 优于 zh-TW）> identifier 稳定兜底。
        return pool.sorted { a, b in
            let ra = rank(a.quality), rb = rank(b.quality)
            if ra != rb { return ra > rb }
            let ea = a.language == languageCode ? 1 : 0
            let eb = b.language == languageCode ? 1 : 0
            if ea != eb { return ea > eb }
            return a.identifier < b.identifier
        }.first
    }

    /// 当前语言是否已安装 增强/高级 音质人声（用于提示用户下载更真实的人声）。
    nonisolated static func hasEnhancedVoice(for language: AnnounceLanguage) -> Bool {
        let prefix = String(language.voiceCode.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(prefix) && ($0.quality == .enhanced || $0.quality == .premium)
        }
    }
}
