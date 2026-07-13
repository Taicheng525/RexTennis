import AVFoundation

/// 人群「喊队名加油」（完全离线）。
///
/// 队名口号经 TTS 渲染后，与真实人群欢呼垫底一起**离线烘焙**成一段成品音频
/// （多声部变调 + 错位起声 + 体育场混响），运行时用 AVAudioPlayer 播放——
/// 无实时引擎，从根上杜绝路由变化导致的 disconnected 崩溃。
/// MainActor 串行化 cache 访问（并发写字典曾导致堆损坏崩溃）。
@MainActor
final class ChantSynth {

    /// 成品混音缓存：key = "队名|语言"
    private var mixCache: [String: Data] = [:]
    /// 进行中的烘焙（去重：prewarm 与点击不会重复烘焙同一队名）
    private var inFlight: [String: Task<Data?, Never>] = [:]
    private var bedBuffer: AVAudioPCMBuffer?
    private var player: AVAudioPlayer?

    // MARK: - 对外接口

    /// 为一个队名预热（比赛开始时调用，首次点击零等待）。
    func prewarm(name: String, language: AnnounceLanguage) {
        Task { [weak self] in
            _ = await self?.mixData(name: name, language: language)
        }
    }

    /// 播放「喊 name 加油」。
    func play(name: String, language: AnnounceLanguage) {
        Task { [weak self] in
            guard let self else { return }
            guard let data = await self.mixData(name: name, language: language) else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.duckOthers])
            try? session.setActive(true)
            self.player?.stop()
            self.player = try? AVAudioPlayer(data: data)
            self.player?.play()
        }
    }

    func stop() {
        player?.stop()
    }

    // MARK: - 烘焙

    /// 口号文本：中文「XX，加油！」×2，英文 "Let's go NAME, let's go!"
    private func chantText(name: String, zh: Bool) -> String {
        zh ? "\(name)，加油！\(name)，加油！" : "Let's go \(name), let's go! \(name)! \(name)!"
    }

    /// 取（或烘焙）某队的成品混音（去重 + 失败重试一次）。
    private func mixData(name: String, language: AnnounceLanguage) async -> Data? {
        let key = "\(name)|\(language.rawValue)"
        if let hit = mixCache[key] { return hit }
        if let running = inFlight[key] { return await running.value }

        let task = Task { [weak self] () -> Data? in
            guard let self else { return nil }
            var data = await self.bakeMix(name: name, language: language)
            if data == nil {   // 偶发被会话活动打断：稍候重试一次
                try? await Task.sleep(nanoseconds: 250_000_000)
                data = await self.bakeMix(name: name, language: language)
            }
            return data
        }
        inFlight[key] = task
        let data = await task.value
        inFlight[key] = nil
        if let data { mixCache[key] = data }
        return data
    }

    /// 单次烘焙。
    private func bakeMix(name: String, language: AnnounceLanguage) async -> Data? {
        let zh = name.containsCJKText || language == .chinese
        let text = chantText(name: name, zh: zh)
        let code = name.containsCJKText ? "zh-CN" : language.voiceCode

        // 男女两个声部（可用则两个）
        var voices: [AVSpeechSynthesisVoice] = []
        for gender in [UmpireVoice.female, .male] {
            if let v = Announcer.pickVoice(languageCode: code, umpire: gender),
               !voices.contains(where: { $0.identifier == v.identifier }) {
                voices.append(v)
            }
        }
        guard !voices.isEmpty else { return nil }

        var chants: [AVAudioPCMBuffer] = []
        for voice in voices {
            if let rendered = await TTSRender.render(text: text, voice: voice,
                                                     rate: AVSpeechUtteranceDefaultSpeechRate * 1.02,
                                                     pitch: 1.12) {
                chants.append(rendered)
            }
        }
        guard !chants.isEmpty else { return nil }

        loadBedIfNeeded()
        return await OfflineFX.bakeCrowdChantAsync(chants: chants, bed: bedBuffer)
    }

    private func loadBedIfNeeded() {
        guard bedBuffer == nil,
              let url = Bundle.main.url(forResource: "cheer", withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                         frameCapacity: AVAudioFrameCount(file.length)) else { return }
        try? file.read(into: raw)
        bedBuffer = TTSRender.convertToStandard(raw)
    }
}

extension String {
    /// 是否包含中日韩表意文字（供口号/播报选择语音）。
    var containsCJKText: Bool {
        unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value) ||
            (0x3400...0x4DBF).contains($0.value) ||
            (0xF900...0xFAFF).contains($0.value)
        }
    }
}
