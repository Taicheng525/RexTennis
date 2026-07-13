import AVFoundation

/// 程序化合成的三种「欢呼」音效，比赛中手动触发。完全离线、无需任何音频素材。
/// - applause：全场掌声（大量随机拍手脉冲叠加）
/// - cheer：人群欢呼（带通噪声 + 起伏包络）
/// - horn：助威号角（双音锯齿波）
final class SoundEffects {

    enum Kind: String, CaseIterable, Identifiable {
        case applause, cheer, horn
        var id: String { rawValue }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let sampleRate: Double = 44_100
    private var cache: [Kind: AVAudioPCMBuffer] = [:]

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// 播放指定音效（打断上一个，避免叠加过响）。
    func play(_ kind: Kind) {
        ensureSession()
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            return
        }
        let buffer = cache[kind] ?? {
            let b = Self.makeBuffer(kind, format: format, sampleRate: sampleRate)
            cache[kind] = b
            return b
        }()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func ensureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    // MARK: - 合成

    private static func makeBuffer(_ kind: Kind, format: AVAudioFormat, sampleRate sr: Double) -> AVAudioPCMBuffer {
        let duration: Double
        switch kind {
        case .applause: duration = 1.9
        case .cheer: duration = 2.0
        case .horn: duration = 1.1
        }
        let count = Int(duration * sr)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        let p = buffer.floatChannelData![0]
        for i in 0..<count { p[i] = 0 }

        switch kind {
        case .applause: synthApplause(p, count, sr)
        case .cheer: synthCheer(p, count, sr)
        case .horn: synthHorn(p, count, sr)
        }
        normalize(p, count, peak: 0.92)
        return buffer
    }

    /// 掌声：约 170 个随机分布的短拍手脉冲（低通白噪声 + 快速衰减）。
    private static func synthApplause(_ p: UnsafeMutablePointer<Float>, _ n: Int, _ sr: Double) {
        let clapLen = max(Int(0.018 * sr), 1)
        for _ in 0..<170 {
            let start = Int.random(in: 0..<max(1, n - clapLen))
            let amp = Float.random(in: 0.15...0.5)
            var lp: Float = 0
            for j in 0..<clapLen {
                let env = expf(-Float(j) / Float(clapLen) * 5)
                let white = Float.random(in: -1...1)
                lp = lp * 0.45 + white * 0.55          // 轻低通，去掉刺耳高频
                p[start + j] += lp * env * amp
            }
        }
        applyEnvelope(p, n, sr, attack: 0.15, release: 0.7)
    }

    /// 人群欢呼：带通噪声 + 多频低速调幅，模拟「哗——」的起伏。
    private static func synthCheer(_ p: UnsafeMutablePointer<Float>, _ n: Int, _ sr: Double) {
        var lp: Float = 0
        for i in 0..<n {
            let white = Float.random(in: -1...1)
            lp = lp * 0.90 + white * 0.10              // 低通分量
            let band = white - lp                       // 高通分量
            let t = Float(i) / Float(sr)
            let am = 0.65
                + 0.20 * sinf(2 * .pi * 3.5 * t)
                + 0.10 * sinf(2 * .pi * 6.0 * t + 1.2)
            p[i] = (lp * 0.55 + band * 0.45) * am
        }
        applyEnvelope(p, n, sr, attack: 0.30, release: 0.6)
    }

    /// 助威号角：两个音（约 415 / 622 Hz）的锯齿波叠加，平稳持续。
    private static func synthHorn(_ p: UnsafeMutablePointer<Float>, _ n: Int, _ sr: Double) {
        let f1: Float = 415, f2: Float = 622
        func saw(_ f: Float, _ t: Float) -> Float {
            let x = t * f
            return 2 * (x - floorf(x + 0.5))
        }
        var lp: Float = 0
        for i in 0..<n {
            let t = Float(i) / Float(sr)
            let raw = saw(f1, t) * 0.6 + saw(f2, t) * 0.4
            lp = lp * 0.55 + raw * 0.45                 // 柔化高次谐波
            p[i] = lp * 0.55
        }
        applyEnvelope(p, n, sr, attack: 0.02, release: 0.10)
    }

    /// 线性淡入淡出包络。
    private static func applyEnvelope(_ p: UnsafeMutablePointer<Float>, _ n: Int, _ sr: Double,
                                      attack: Double, release: Double) {
        let a = max(Int(attack * sr), 1)
        let r = max(Int(release * sr), 1)
        for i in 0..<min(a, n) { p[i] *= Float(i) / Float(a) }
        for k in 0..<min(r, n) {
            let i = n - 1 - k
            p[i] *= Float(k) / Float(r)
        }
    }

    /// 归一化到目标峰值，避免叠加削波。
    private static func normalize(_ p: UnsafeMutablePointer<Float>, _ n: Int, peak: Float) {
        var maxAbs: Float = 0.0001
        for i in 0..<n { maxAbs = max(maxAbs, abs(p[i])) }
        let gain = peak / maxAbs
        for i in 0..<n { p[i] *= gain }
    }
}
