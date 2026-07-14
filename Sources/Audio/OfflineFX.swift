import AVFoundation

/// 离线音效烘焙：用 AVAudioEngine 手动渲染模式把效果链一次性渲染成 WAV 数据，
/// 运行时用 AVAudioPlayer 播放成品——没有实时引擎，就没有
/// 「player started when in a disconnected state」这类路由竞争崩溃。
enum OfflineFX {

    /// 三层声部参数（音分偏移, 变速, 起声延迟秒, 音量）。
    /// 音分差收敛在 ±45、不变速——大音分差+变速会产生「外星人合唱」失真；
    /// 人群感主要靠小的错位起声与两个不同人声。
    private static let chantLayers: [(pitch: Float, rate: Float, delay: Double, gain: Float)] = [
        (-45, 1.0, 0.00, 0.9),
        (  0, 1.0, 0.05, 1.0),
        ( 40, 1.0, 0.11, 0.85),
    ]

    // MARK: - 对外：两种烘焙

    /// 人群喊名混音：真实欢呼垫底 + 多声部变调口号 + 体育场混响 → WAV。
    static func bakeCrowdChant(chants: [AVAudioPCMBuffer], bed: AVAudioPCMBuffer?) -> Data? {
        guard !chants.isEmpty else { return nil }
        let format = TTSRender.standardFormat
        let engine = AVAudioEngine()
        // 必须先启用手动渲染模式再接线——该调用会重置引擎并断开既有连接，
        // 后启用会导致 play 时 disconnected 崩溃
        guard enableManual(engine) else { return nil }

        // 垫底
        let bedPlayer = AVAudioPlayerNode()
        engine.attach(bedPlayer)
        engine.connect(bedPlayer, to: engine.mainMixerNode, format: format)

        // 口号声部 → 变调 → 子混音 → 混响
        // 关键：混响只有一个输入总线，多条声部链直连会互相顶掉（先连的变
        // disconnected，play 即崩）；必须经多输入的子混音器汇流后再进混响。
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 26   // 混响过重是「外星人感」的来源之一
        let submix = AVAudioMixerNode()
        engine.attach(reverb)
        engine.attach(submix)
        engine.connect(submix, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        var players: [(AVAudioPlayerNode, AVAudioPCMBuffer)] = []
        var chantEnd: Double = 0
        var index = 0
        for chant in chants.prefix(2) where chant.frameLength > 0 {
            let chantDur = Double(chant.frameLength) / format.sampleRate
            for layer in chantLayers {
                let player = AVAudioPlayerNode()
                let pitch = AVAudioUnitTimePitch()
                pitch.pitch = layer.pitch + Float.random(in: -12...12)
                pitch.rate = layer.rate
                engine.attach(player)
                engine.attach(pitch)
                engine.connect(player, to: pitch, format: format)
                engine.connect(pitch, to: submix, format: format)
                player.volume = layer.gain * 0.85   // 口号要清晰可辨

                let delaySec = 0.35 + layer.delay + Double(index % 2) * 0.03
                guard let padded = TTSRender.padded(chant, leadingSeconds: delaySec) else { continue }
                players.append((player, padded))
                chantEnd = max(chantEnd, delaySec + chantDur / Double(layer.rate))
                index += 1
            }
        }

        let bedDur = bed.map { Double($0.frameLength) / format.sampleRate } ?? 0
        let duration = max(bedDur, chantEnd + 1.6)   // 留混响尾

        return renderOffline(engine: engine, duration: duration) {
            if let bed, bed.frameLength > 0 {
                bedPlayer.volume = 0.60   // 垫底压低，让口号听得清
                bedPlayer.scheduleBuffer(bed, at: nil, options: [], completionHandler: nil)
                bedPlayer.play()
            }
            for (player, buffer) in players {
                player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                player.play()
            }
        }
    }

    /// 现场 PA 报分：短延迟回声（喇叭反射）+ 球场混响 → WAV。
    static func bakeStadiumPA(_ voice: AVAudioPCMBuffer) -> Data? {
        guard voice.frameLength > 0 else { return nil }
        let format = TTSRender.standardFormat
        let engine = AVAudioEngine()
        guard enableManual(engine) else { return nil }

        let player = AVAudioPlayerNode()
        let echo = AVAudioUnitDelay()
        let reverb = AVAudioUnitReverb()

        // 体育场 PA 麦克风感：明显但不盖住人声的短回声 + 大空间混响
        echo.delayTime = 0.14          // 短前反射：喇叭扩声感
        echo.feedback = 24             // 多次反射，像大看台空间
        echo.wetDryMix = 17            // 回声清晰可闻
        echo.lowPassCutoff = 3400      // 回声尾略闷，像远处看台反射

        reverb.loadFactoryPreset(.largeHall)   // 大厅≈体育场，比 largeRoom 更空旷
        reverb.wetDryMix = 22          // 明显的现场空间混响

        engine.attach(player)
        engine.attach(echo)
        engine.attach(reverb)
        engine.connect(player, to: echo, format: format)
        engine.connect(echo, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        let voiceDur = Double(voice.frameLength) / format.sampleRate
        let padded = TTSRender.padded(voice, leadingSeconds: 0.08) ?? voice   // 抬麦停顿

        return renderOffline(engine: engine, duration: voiceDur + 1.7) {
            player.scheduleBuffer(padded, at: nil, options: [], completionHandler: nil)
            player.play()
        }
    }

    // MARK: - 渲染与封装

    private static let chunkFrames: AVAudioFrameCount = 4096

    /// 启用离线手动渲染模式（必须在接线之前调用）。
    private static func enableManual(_ engine: AVAudioEngine) -> Bool {
        (try? engine.enableManualRenderingMode(.offline, format: TTSRender.standardFormat,
                                               maximumFrameCount: chunkFrames)) != nil
    }

    /// 所有烘焙经此串行队列执行（独立 GCD 线程；在 Swift 并发协作线程上
    /// 直接操作 AVAudio 引擎会触发 unsafeForcedSync 警告）。
    private static let bakeQueue = DispatchQueue(label: "rex.offlinefx.bake")

    /// 异步入口：把烘焙调度到串行队列线程执行。
    static func bakeCrowdChantAsync(chants: [AVAudioPCMBuffer], bed: AVAudioPCMBuffer?) async -> Data? {
        await withCheckedContinuation { cont in
            bakeQueue.async { cont.resume(returning: bakeCrowdChant(chants: chants, bed: bed)) }
        }
    }

    static func bakeStadiumPAAsync(_ voice: AVAudioPCMBuffer) async -> Data? {
        await withCheckedContinuation { cont in
            bakeQueue.async { cont.resume(returning: bakeStadiumPA(voice)) }
        }
    }

    /// 跑完 duration 秒渲染，输出 WAV 数据（引擎须已启用手动模式并完成接线）。
    /// ObjC 异常捕获兜底（Swift 捕不了 NSException）。
    private static func renderOffline(engine: AVAudioEngine, duration: Double,
                                      startPlayers: () -> Void) -> Data? {
        run {
            let format = TTSRender.standardFormat
            var failed = false
            let exception = RexCatchException {
                do {
                    try engine.start()
                } catch {
                    failed = true
                    return
                }
                startPlayers()
            }
            if failed || exception != nil { engine.stop(); return nil }

            let totalFrames = AVAudioFramePosition(duration * format.sampleRate)
            guard let chunk = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                               frameCapacity: chunkFrames) else { return nil }
            // 立体声交织采集
            var samples: [Float] = []
            samples.reserveCapacity(Int(totalFrames) * 2)

            let renderException = RexCatchException {
                while engine.manualRenderingSampleTime < totalFrames {
                    let remain = AVAudioFrameCount(totalFrames - engine.manualRenderingSampleTime)
                    let n = min(chunkFrames, remain)
                    guard let status = try? engine.renderOffline(n, to: chunk), status == .success,
                          let data = chunk.floatChannelData else { break }
                    let frames = Int(chunk.frameLength)
                    let right = format.channelCount > 1 ? data[1] : data[0]
                    for i in 0..<frames {
                        samples.append(data[0][i])
                        samples.append(right[i])
                    }
                }
            }
            engine.stop()
            guard renderException == nil, !samples.isEmpty else { return nil }
            return wavData(interleaved: samples, channels: 2, sampleRate: Int(format.sampleRate))
        }
    }

    /// 立即执行闭包（保持原缩进结构的辅助函数）。
    private static func run<T>(_ body: () -> T) -> T { body() }

    /// 交织 Float32 样本 → 16-bit PCM WAV。
    /// 峰值归一化：超过满幅时整体线性压低——硬削波会把响的人声（尤其增强
    /// 人声+混响叠加后）切出明显失真。
    private static func wavData(interleaved samples: [Float], channels: Int, sampleRate: Int) -> Data {
        var peak: Float = 0.0001
        for s in samples { peak = max(peak, abs(s)) }
        let gain: Float = peak > 0.95 ? 0.95 / peak : 1.0

        var pcm = Data(capacity: samples.count * 2)
        for s in samples {
            var v = Int16(max(-1, min(1, s * gain)) * 32767)
            withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
        }
        let blockAlign = channels * 2
        var data = Data()
        func append(_ s: String) { data.append(s.data(using: .ascii)!) }
        func append32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }

        append("RIFF"); append32(UInt32(36 + pcm.count)); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(UInt16(channels))
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate * blockAlign))
        append16(UInt16(blockAlign)); append16(16)
        append("data"); append32(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}
