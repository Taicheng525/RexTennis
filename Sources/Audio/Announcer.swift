import AVFoundation

/// 离线语音播报：TTS 渲染后**离线烘焙**现场 PA 效果（短延迟回声 + 球场混响），
/// 模拟裁判透过场内广播报分的空间感；运行时用 AVAudioPlayer 播放成品，
/// 无实时引擎、无路由竞争崩溃。音频自动路由到已连接的蓝牙耳机。
///
/// - **只报最新**：连续得分 debounce 合并，只播报最后一条。
/// - **按内容选语言**：文本含中文用中文人声（中文队名在英文模式也能读对）。
/// - **文案缓存**：同一比分文案只烘焙一次，之后即点即播。
/// - MainActor 串行化状态访问。
@MainActor
final class Announcer {

    private var sessionConfigured = false
    private var pendingText: String?
    private var pendingWork: DispatchWorkItem?
    private var playTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var cache: [String: Data] = [:]

    /// 合并快速连点的间隔。
    private let debounceDelay: TimeInterval = 0.16

    var language: AnnounceLanguage = .chinese
    var umpire: UmpireVoice = .female
    /// 队名是否含中文（由 VM 在开赛时设置）。含中文时整场固定用中文人声，
    /// 保证队名读得出、且全场只有一个裁判的声音。
    var namesContainCJK: Bool = false

    // MARK: - 对外接口

    /// 朗读一句文案。连续调用只会播报最后一条。
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureSessionIfNeeded()

        pendingText = trimmed
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

        playTask = Task { [weak self] in
            guard let self else { return }
            guard let voice = self.matchVoice() else { return }
            let key = "\(text)|\(voice.identifier)"
            var data = self.cache[key]
            if data == nil {
                // 保持自然音高与接近正常的语速——改音高会让系统人声发音失真、
                // 听感机械（中文尤甚）
                guard let buffer = await TTSRender.render(text: text, voice: voice,
                                                          rate: AVSpeechUtteranceDefaultSpeechRate * 0.94,
                                                          pitch: 1.0) else { return }
                data = await OfflineFX.bakeStadiumPAAsync(buffer)
                if data == nil {   // 偶发失败：稍候重试一次
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    data = await OfflineFX.bakeStadiumPAAsync(buffer)
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

    /// 整场唯一的裁判人声：选中文播报或队名含中文 → 中文人声，否则所选语言人声。
    /// 不再按每句文本切换——那会造成「第三个声音」在场上出现。
    private func matchVoice() -> AVSpeechSynthesisVoice? {
        let code = (language == .chinese || namesContainCJK) ? "zh-CN" : language.voiceCode
        return Self.pickVoice(languageCode: code, umpire: umpire)
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
        // 同音质下，优先精确匹配区域代码（如 zh-CN 优于 zh-TW）。
        return pool.max {
            let r0 = rank($0.quality), r1 = rank($1.quality)
            if r0 != r1 { return r0 < r1 }
            let e0 = $0.language == languageCode ? 1 : 0
            let e1 = $1.language == languageCode ? 1 : 0
            return e0 < e1
        }
    }

    /// 当前语言是否已安装 增强/高级 音质人声（用于提示用户下载更真实的人声）。
    nonisolated static func hasEnhancedVoice(for language: AnnounceLanguage) -> Bool {
        let prefix = String(language.voiceCode.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(prefix) && ($0.quality == .enhanced || $0.quality == .premium)
        }
    }
}
