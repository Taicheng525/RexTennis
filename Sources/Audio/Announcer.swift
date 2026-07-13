import AVFoundation

/// 离线语音播报：配置音频会话并用系统 TTS 朗读文案，自动路由到已连接的蓝牙耳机。
///
/// 关键点：
/// - **只报最新**：连续得分时用 debounce 合并，只播报最后一条；打断上一条时留出足够
///   间隔再朗读，规避 `stopSpeaking` 后立即 `speak` 被系统吞掉、导致「没声音」的坑。
/// - **按内容选语言**：文本含中文则用中文人声，否则用所选语言人声——这样即便英文
///   播报模式下，用户输入的中文队名也能被正确读出，而不是被跳过或错读。
/// - 声音仿温网裁判：英文用英式口音（en-GB），可选男/女，按「性别匹配 → 音质最高」挑选。
final class Announcer {

    private let synthesizer = AVSpeechSynthesizer()
    private var sessionConfigured = false

    private var pendingText: String?
    private var pendingWork: DispatchWorkItem?
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    /// 打断后到重新朗读之间的间隔——足够长以避开 stopSpeaking 的吞音问题，又几乎无感。
    private let relaunchDelay: TimeInterval = 0.16

    var language: AnnounceLanguage = .chinese
    var umpire: UmpireVoice = .female

    /// 朗读一句文案。连续调用只会播报最后一条。
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureSessionIfNeeded()

        pendingText = trimmed
        pendingWork?.cancel()

        // 打断正在朗读的上一条（连点场景）。
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // 延迟一点再真正朗读：合并快速连点，且给 stopSpeaking 留出恢复时间。
        let work = DispatchWorkItem { [weak self] in self?.flushPending() }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + relaunchDelay, execute: work)
    }

    /// 立即停止并清空待播（撤销、新比赛时清场，且不发出任何声音）。
    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        pendingText = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func flushPending() {
        guard let text = pendingText else { return }
        pendingText = nil

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: text)
        // 裁判风格：稍慢而克制的语速、略沉的音色、报分前的短停顿
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 0.94
        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    /// 当前语言是否已安装 增强/高级 音质人声（用于提示用户下载更真实的人声）。
    static func hasEnhancedVoice(for language: AnnounceLanguage) -> Bool {
        let prefix = String(language.voiceCode.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(prefix) && ($0.quality == .enhanced || $0.quality == .premium)
        }
    }

    /// 配置播放会话：`.playback` 默认走蓝牙 A2DP；`.duckOthers` 播报时压低其他音乐、结束自动恢复。
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

    /// 按「文本内容语言」+ 裁判性别挑人声：含中文 → 中文人声，否则用所选语言人声。
    private func voice(for text: String) -> AVSpeechSynthesisVoice? {
        let code = text.containsCJK ? "zh-CN" : language.voiceCode
        let key = "\(code)|\(umpire.rawValue)"
        if let cached = voiceCache[key] { return cached }
        let picked = Self.pickVoice(languageCode: code, umpire: umpire)
        if let picked { voiceCache[key] = picked }
        return picked
    }

    /// 从系统人声中挑选：先按性别过滤（无匹配则退回全部），再取音质最高的。
    static func pickVoice(languageCode: String, umpire: UmpireVoice) -> AVSpeechSynthesisVoice? {
        let prefix = String(languageCode.prefix(2))
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == languageCode || $0.language.hasPrefix(prefix) }
        guard !all.isEmpty else { return AVSpeechSynthesisVoice(language: languageCode) }

        let wanted: AVSpeechSynthesisVoiceGender = umpire == .female ? .female : .male
        let genderMatched = all.filter { $0.gender == wanted }
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
}

private extension String {
    /// 是否包含中日韩统一表意文字（用于判断是否需要中文人声）。
    var containsCJK: Bool {
        unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value) ||   // CJK 统一表意
            (0x3400...0x4DBF).contains($0.value) ||   // 扩展 A
            (0xF900...0xFAFF).contains($0.value)      // 兼容表意
        }
    }
}
