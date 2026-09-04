import AVFoundation

/// 内置裁判人声片段（随包提供的高质量预录音频，按 语言 × 性别 分目录）。
///
/// 用途：用户手机没装「增强」系统人声时，用这套音频代替机械的默认 TTS。
/// 片段以 `AnnouncementBuilder.Phrase.clipID` 命名，一句播报 = 多个片段拼接后
/// 再走与系统 TTS 相同的现场 PA 烘焙，听感与原流程一致。
///
/// 目录：`Voices/<zh|en>_<female|male>/<clipID>.m4a`（Bundle 内 folder reference）。
enum VoiceClips {

    /// 该语言 + 性别的内置音频是否随包提供（以一个必备片段是否存在为准）。
    static func available(language: AnnounceLanguage, umpire: UmpireVoice) -> Bool {
        url(for: "score_0_0", language: language, umpire: umpire) != nil
    }

    /// 片段目录名。
    static func folder(language: AnnounceLanguage, umpire: UmpireVoice) -> String {
        "\(language == .chinese ? "zh" : "en")_\(umpire.rawValue)"
    }

    static func url(for clipID: String, language: AnnounceLanguage, umpire: UmpireVoice) -> URL? {
        Bundle.main.url(forResource: clipID, withExtension: "m4a",
                        subdirectory: "Voices/\(folder(language: language, umpire: umpire))")
    }

    /// 把若干片段读成标准格式 PCM 并顺序拼接，片段之间留 `gap` 秒静音。
    /// 任一片段缺失返回 nil（调用方退回系统 TTS）。
    /// 纯磁盘读取 + 内存拷贝，1–2 秒的 AAC 片段解码约几毫秒。
    static func render(clipIDs: [String], language: AnnounceLanguage, umpire: UmpireVoice,
                       gap: Double = 0.22) -> AVAudioPCMBuffer? {
        guard !clipIDs.isEmpty else { return nil }
        var parts: [AVAudioPCMBuffer] = []
        for (i, id) in clipIDs.enumerated() {
            guard let url = url(for: id, language: language, umpire: umpire),
                  let pcm = load(url) else { return nil }
            parts.append(i == 0 ? pcm : (TTSRender.padded(pcm, leadingSeconds: gap) ?? pcm))
        }
        return concat(parts)
    }

    /// 在后台串行队列上渲染（与 OfflineFX 的烘焙共用同一线程模型）。
    static func renderAsync(clipIDs: [String], language: AnnounceLanguage, umpire: UmpireVoice) async -> AVAudioPCMBuffer? {
        await withCheckedContinuation { cont in
            queue.async { cont.resume(returning: render(clipIDs: clipIDs, language: language, umpire: umpire)) }
        }
    }

    private static let queue = DispatchQueue(label: "rex.voiceclips.load")

    private static func load(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let len = AVAudioFrameCount(file.length)
        guard len > 0,
              let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: len),
              (try? file.read(into: raw)) != nil else { return nil }
        return TTSRender.convertToStandard(raw)
    }

    private static func concat(_ parts: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let first = parts.first else { return nil }
        if parts.count == 1 { return first }
        let total = parts.reduce(0) { $0 + $1.frameLength }
        guard let out = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: total),
              let d = out.floatChannelData else { return nil }
        var offset = 0
        for p in parts {
            guard let s = p.floatChannelData else { continue }
            for ch in 0..<Int(first.format.channelCount) {
                memcpy(d[ch].advanced(by: offset), s[ch], Int(p.frameLength) * 4)
            }
            offset += Int(p.frameLength)
        }
        out.frameLength = total
        return out
    }
}
