import AVFoundation

/// 离线语音播报：配置音频会话并用系统 TTS 朗读文案，自动路由到已连接的蓝牙耳机。
final class Announcer {

    private let synthesizer = AVSpeechSynthesizer()
    private var sessionConfigured = false

    var language: AnnounceLanguage = .chinese

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

    /// 朗读一句文案（追加到队列，不打断正在播报的内容）。
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configureSessionIfNeeded()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: language.voiceCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    /// 立即停止播报（如撤销或新比赛时清场）。
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
