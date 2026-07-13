import AVFoundation

/// 系统 TTS 离线渲染工具：把文本渲染成标准格式 PCM，供音频引擎做后期处理
/// （报分的现场 PA 回声、喊名的人群化多声部等）。
enum TTSRender {

    /// 引擎图统一使用的标准格式（Float32 / 44.1kHz / **立体声**）。
    /// 效果节点（变调/延迟）不接受单声道，TTS 原始输出（Int16/22kHz/单声道）
    /// 直连会让连接抛 -10868；统一先转到该格式。
    static let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    /// 渲染期间保活的 synthesizer（write 回调异步，局部变量会被提前释放）。
    private static var activeSynths: [ObjectIdentifier: AVSpeechSynthesizer] = [:]
    private static let synthLock = NSLock()

    /// 把文本渲染为标准格式 PCM buffer（nil = 渲染失败）。
    static func render(text: String,
                       voice: AVSpeechSynthesisVoice,
                       rate: Float,
                       pitch: Float) async -> AVAudioPCMBuffer? {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        let synth = AVSpeechSynthesizer()
        synthLock.lock(); activeSynths[ObjectIdentifier(synth)] = synth; synthLock.unlock()

        let raw: AVAudioPCMBuffer? = await withCheckedContinuation { continuation in
            var chunks: [AVAudioPCMBuffer] = []
            var finished = false
            func finish() {
                guard !finished else { return }
                finished = true
                synthLock.lock(); activeSynths[ObjectIdentifier(synth)] = nil; synthLock.unlock()
                continuation.resume(returning: concat(chunks))
            }
            // 在普通 GCD 线程调用（避免在 Swift 并发协作线程触发系统的
            // unsafeForcedSync 警告）
            DispatchQueue.global(qos: .userInitiated).async {
                synth.write(utterance) { buffer in
                    guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                    if pcm.frameLength == 0 {
                        finish()
                    } else if let copy = copyBuffer(pcm) {
                        chunks.append(copy)
                    }
                }
            }
            // 兜底：极端情况下没有零长度结尾包
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { finish() }
        }
        guard let raw else { return nil }
        return convertToStandard(raw)
    }

    /// 任意 PCM → 标准格式。
    static func convertToStandard(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard src.frameLength > 0 else { return nil }
        if src.format == standardFormat { return src }
        guard let converter = AVAudioConverter(from: src.format, to: standardFormat) else { return nil }
        let ratio = standardFormat.sampleRate / src.format.sampleRate
        let capacity = AVAudioFrameCount(Double(src.frameLength) * ratio) + 4096
        guard let out = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: capacity) else { return nil }
        var fed = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return src
        }
        return (err == nil && out.frameLength > 0) ? out : nil
    }

    /// 在 buffer 前补静音（错位起声/起始停顿用）。支持多声道非交织格式。
    static func padded(_ src: AVAudioPCMBuffer, leadingSeconds: Double) -> AVAudioPCMBuffer? {
        let lead = AVAudioFrameCount(leadingSeconds * src.format.sampleRate)
        let total = lead + src.frameLength
        guard let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: total),
              let sData = src.floatChannelData, let dData = out.floatChannelData else { return nil }
        out.frameLength = total
        for ch in 0..<Int(src.format.channelCount) {
            memset(dData[ch], 0, Int(total) * 4)
            memcpy(dData[ch].advanced(by: Int(lead)), sData[ch], Int(src.frameLength) * 4)
        }
        return out
    }

    // MARK: - 私有

    /// TTS 原始 chunk 拷贝（保持来源格式，可能是交织 Int16 单声道——按字节整块拷）。
    private static func copyBuffer(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let dst = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: src.frameLength) else { return nil }
        dst.frameLength = src.frameLength
        let srcList = UnsafeMutableAudioBufferListPointer(src.mutableAudioBufferList)
        let dstList = UnsafeMutableAudioBufferListPointer(dst.mutableAudioBufferList)
        for (s, d) in zip(srcList, dstList) where s.mData != nil && d.mData != nil {
            memcpy(d.mData!, s.mData!, Int(s.mDataByteSize))
        }
        return dst
    }

    private static func concat(_ chunks: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let first = chunks.first else { return nil }
        let total = chunks.reduce(0) { $0 + $1.frameLength }
        guard let out = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: total) else { return nil }
        let bpf = Int(first.format.streamDescription.pointee.mBytesPerFrame)
        let outList = UnsafeMutableAudioBufferListPointer(out.mutableAudioBufferList)
        for c in chunks {
            let cList = UnsafeMutableAudioBufferListPointer(c.mutableAudioBufferList)
            for (i, s) in cList.enumerated() where s.mData != nil {
                if let d = outList[i].mData {
                    memcpy(d.advanced(by: Int(out.frameLength) * bpf), s.mData!, Int(c.frameLength) * bpf)
                }
            }
            out.frameLength += c.frameLength
        }
        return out
    }
}

extension String {
    /// 是否包含中日韩表意文字（用于判断队名/文本是否需要中文人声）。
    var containsCJKText: Bool {
        unicodeScalars.contains {
            (0x4E00...0x9FFF).contains($0.value) ||
            (0x3400...0x4DBF).contains($0.value) ||
            (0xF900...0xFAFF).contains($0.value)
        }
    }
}
