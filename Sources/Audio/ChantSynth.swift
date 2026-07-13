import AVFoundation

/// 人群「喊队名加油」合成器（完全离线）。
///
/// 原理：把队名口号用系统 TTS 渲染成 PCM，再做「人群化」处理——
/// 男女两个声部 × 三层变调（±音分）+ 错位起声 + 体育场混响，
/// 全部垫在真实人群欢呼录音之上，听感接近场边人群齐喊，而非机器读名。
/// 渲染结果按（文本+声部）缓存，比赛开始时预热，点击即放。
final class ChantSynth: NSObject {

    private let engine = AVAudioEngine()
    private var chantPlayers: [AVAudioPlayerNode] = []
    private var pitchUnits: [AVAudioUnitTimePitch] = []
    private let bedPlayer = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()

    /// 渲染缓存：key = "文本|voiceId"
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var bedBuffer: AVAudioPCMBuffer?
    private var wired = false

    /// 三层声部的（音分偏移, 变速, 起声延迟秒, 音量）——制造人群参差感
    private static let layers: [(pitch: Float, rate: Float, delay: Double, gain: Float)] = [
        (-160, 0.97, 0.00, 0.85),
        (   0, 1.00, 0.055, 0.95),
        ( 170, 1.04, 0.12, 0.80),
    ]

    // MARK: - 对外接口

    /// 为一个队名预热（比赛开始时调用，首次点击零等待）。
    func prewarm(name: String, language: AnnounceLanguage) {
        Task.detached(priority: .utility) { [weak self] in
            _ = await self?.renderedChants(name: name, language: language)
        }
    }

    /// 播放「喊 name 加油」。
    func play(name: String, language: AnnounceLanguage) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let chants = await self.renderedChants(name: name, language: language)
            guard !chants.isEmpty else { return }
            self.startPlayback(chants: chants)
        }
    }

    func stop() {
        guard wired else { return }
        chantPlayers.forEach { $0.stop() }
        bedPlayer.stop()
    }

    // MARK: - 渲染

    /// 口号文本：中文「XX加油！XX加油！」，英文 "Let's go NAME, let's go!"
    private func chantText(name: String, zh: Bool) -> String {
        zh ? "\(name)，加油！\(name)，加油！" : "Let's go \(name), let's go! \(name)! \(name)!"
    }

    /// 渲染男女两个声部的口号 PCM（可用则两个，否则一个）。
    private func renderedChants(name: String, language: AnnounceLanguage) async -> [AVAudioPCMBuffer] {
        let zh = name.containsCJKText || language == .chinese
        let text = chantText(name: name, zh: zh)
        let code = name.containsCJKText ? "zh-CN" : language.voiceCode

        var voices: [AVSpeechSynthesisVoice] = []
        for gender in [UmpireVoice.female, .male] {
            if let v = Announcer.pickVoice(languageCode: code, umpire: gender),
               !voices.contains(where: { $0.identifier == v.identifier }) {
                voices.append(v)
            }
        }
        guard !voices.isEmpty else { return [] }

        var result: [AVAudioPCMBuffer] = []
        for voice in voices {
            let key = "\(text)|\(voice.identifier)"
            if let hit = cache[key] {
                result.append(hit)
            } else if let rendered = await Self.renderTTS(text: text, voice: voice) {
                cache[key] = rendered
                result.append(rendered)
            }
        }
        return result
    }

    /// 渲染期间保活的 synthesizer（write 回调是异步的，局部变量会被提前释放）。
    private static var activeSynths: [ObjectIdentifier: AVSpeechSynthesizer] = [:]
    private static let synthLock = NSLock()

    /// 把一段文本用指定 voice 渲染为单个 PCM buffer。
    private static func renderTTS(text: String, voice: AVSpeechSynthesisVoice) async -> AVAudioPCMBuffer? {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.02   // 口号節奏稍快
        utterance.pitchMultiplier = 1.12                              // 更亢奋
        let synth = AVSpeechSynthesizer()
        synthLock.lock(); activeSynths[ObjectIdentifier(synth)] = synth; synthLock.unlock()

        return await withCheckedContinuation { continuation in
            var chunks: [AVAudioPCMBuffer] = []
            var finished = false
            func finish() {
                guard !finished else { return }
                finished = true
                synthLock.lock(); activeSynths[ObjectIdentifier(synth)] = nil; synthLock.unlock()
                continuation.resume(returning: Self.concat(chunks))
            }
            synth.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    finish()
                } else if let copy = Self.copyBuffer(pcm) {
                    chunks.append(copy)
                }
            }
            // 兜底：极端情况下没有零长度结尾包
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { finish() }
        }
    }

    private static func copyBuffer(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let dst = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: src.frameLength) else { return nil }
        dst.frameLength = src.frameLength
        let bytes = Int(src.frameLength) * Int(src.format.streamDescription.pointee.mBytesPerFrame)
        if let s = src.audioBufferList.pointee.mBuffers.mData,
           let d = dst.audioBufferList.pointee.mBuffers.mData {
            memcpy(d, s, bytes)
        }
        return dst
    }

    private static func concat(_ chunks: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let first = chunks.first else { return nil }
        let total = chunks.reduce(0) { $0 + $1.frameLength }
        guard let out = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: total) else { return nil }
        for c in chunks {
            let bytes = Int(c.frameLength) * Int(c.format.streamDescription.pointee.mBytesPerFrame)
            if let s = c.audioBufferList.pointee.mBuffers.mData,
               let d = out.audioBufferList.pointee.mBuffers.mData {
                memcpy(d.advanced(by: Int(out.frameLength) * Int(out.format.streamDescription.pointee.mBytesPerFrame)), s, bytes)
            }
            out.frameLength += c.frameLength
        }
        return out
    }

    // MARK: - 播放（人群化处理）

    private func wireIfNeeded(format: AVAudioFormat) {
        guard !wired else { return }

        // 人群欢呼垫底
        engine.attach(bedPlayer)
        engine.connect(bedPlayer, to: engine.mainMixerNode, format: nil)
        if let url = Bundle.main.url(forResource: "cheer", withExtension: "m4a"),
           let file = try? AVAudioFile(forReading: url),
           let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                      frameCapacity: AVAudioFrameCount(file.length)) {
            try? file.read(into: buf)
            bedBuffer = buf
        }

        // 六个口号声部（2 voice × 3 层）走 变调 → 体育场混响
        engine.attach(reverb)
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 52
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            engine.attach(player)
            engine.attach(pitch)
            engine.connect(player, to: pitch, format: format)
            engine.connect(pitch, to: reverb, format: format)
            chantPlayers.append(player)
            pitchUnits.append(pitch)
        }
        wired = true
    }

    private func startPlayback(chants: [AVAudioPCMBuffer]) {
        guard let format = chants.first?.format else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)

        wireIfNeeded(format: format)
        if !engine.isRunning { try? engine.start() }
        stopNodesOnly()

        // 垫底人群声（稍低音量）
        if let bed = bedBuffer {
            bedPlayer.volume = 0.75
            bedPlayer.scheduleBuffer(bed, at: nil, options: .interrupts, completionHandler: nil)
            bedPlayer.play()
        }

        // 口号声部：每个 voice × 3 层，错位起声 + 变调
        let sr = format.sampleRate
        var index = 0
        for chant in chants.prefix(2) {
            for layer in Self.layers {
                guard index < chantPlayers.count else { break }
                let player = chantPlayers[index]
                let pitch = pitchUnits[index]
                pitch.pitch = layer.pitch + Float.random(in: -25...25)
                pitch.rate = layer.rate
                player.volume = layer.gain * 0.62   // 融进人群，不能盖过垫底声

                // 前置静音实现错位起声（人群从 0.35s 处进）
                let delaySec = 0.35 + layer.delay + Double(index % 2) * 0.03
                if let padded = Self.padded(chant, leadingSeconds: delaySec, sampleRate: sr) {
                    player.scheduleBuffer(padded, at: nil, options: .interrupts, completionHandler: nil)
                    player.play()
                }
                index += 1
            }
        }
    }

    private func stopNodesOnly() {
        chantPlayers.forEach { $0.stop() }
        bedPlayer.stop()
    }

    /// 在 buffer 前补 leadingSeconds 的静音。
    private static func padded(_ src: AVAudioPCMBuffer, leadingSeconds: Double, sampleRate: Double) -> AVAudioPCMBuffer? {
        let lead = AVAudioFrameCount(leadingSeconds * sampleRate)
        let total = lead + src.frameLength
        guard let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: total) else { return nil }
        out.frameLength = total
        let bpf = Int(src.format.streamDescription.pointee.mBytesPerFrame)
        if let d = out.audioBufferList.pointee.mBuffers.mData {
            memset(d, 0, Int(total) * bpf)
            if let s = src.audioBufferList.pointee.mBuffers.mData {
                memcpy(d.advanced(by: Int(lead) * bpf), s, Int(src.frameLength) * bpf)
            }
        }
        return out
    }
}

extension String {
    /// 是否包含中日韩表意文字（与 Announcer 中判定一致，供口号选择语音）。
    var containsCJKText: Bool {
        unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value) ||
            (0x3400...0x4DBF).contains($0.value) ||
            (0xF900...0xFAFF).contains($0.value)
        }
    }
}
