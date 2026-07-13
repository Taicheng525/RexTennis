import AVFoundation

/// 离线语音播报：配置音频会话并用系统 TTS 朗读文案，自动路由到已连接的蓝牙耳机。
///
/// 声音选择仿温网裁判：英文用英式口音（en-GB），可选男/女裁判——
/// 按「性别匹配 → 音质最高（premium > enhanced > default）」从系统已装人声中挑选。
final class Announcer {

    private let synthesizer = AVSpeechSynthesizer()
    private var sessionConfigured = false

    var language: AnnounceLanguage = .chinese { didSet { cachedVoice = nil } }
    var umpire: UmpireVoice = .female { didSet { cachedVoice = nil } }

    /// 选定的人声缓存（语言/性别变更时失效）。
    private var cachedVoice: AVSpeechSynthesisVoice??

    /// 配置播放会话：`.playback` 默认走蓝牙 A2DP；`.duckOthers` 播报时压低其他音乐、结束自动恢复。
    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            sessionConfigured = true
        } catch {
            // 会话配置失败不阻断流程：仍尝试用默认输出朗读。
            sessionConfigured = false
        }
    }

    /// 朗读一句文案。**打断上一条未念完的**——快速连续得分时只播报最新比分，不排队。
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureSessionIfNeeded()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = selectedVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    /// 立即停止播报（如撤销或新比赛时清场）。
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - 人声挑选

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoice { return cached }
        let voice = Self.pickVoice(languageCode: language.voiceCode, umpire: umpire)
        cachedVoice = voice
        return voice
    }

    /// 从系统人声中挑选：先按性别过滤（无匹配则退回全部），再取音质最高的。
    static func pickVoice(languageCode: String, umpire: UmpireVoice) -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == languageCode }
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
        return pool.max { rank($0.quality) < rank($1.quality) }
    }
}
