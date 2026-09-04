import AVFoundation

/// 全局唯一的音频会话管理。
///
/// 两件事决定「点击到出声」的延迟：
/// 1. **会话只配置一次**。之前语音与音效各自反复 `setCategory`（mode 还不同），
///    每次切换都触发系统重配输出路由，点击后先等路由再出声。
/// 2. **比赛期间用一条静音循环保活**。音频硬件与蓝牙 A2DP 链路在几秒无声后会
///    进入空闲，下一次出声要重新拉起链路（蓝牙耳机上可达 0.3–0.6 秒，开头还可能
///    被吞掉）。保活让链路始终处于「正在播」状态，音效/报分即点即出。
@MainActor
final class AudioSessionManager {

    static let shared = AudioSessionManager()

    private var configured = false
    private var keepAlive: AVAudioPlayer?

    private init() {}

    /// 配置并激活会话（幂等；已激活时几乎零开销）。
    func activate() {
        let session = AVAudioSession.sharedInstance()
        if !configured {
            // `.playback`：走蓝牙、锁屏继续；`.duckOthers`：出声时压低其他 App 的音乐。
            try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
            // 更短的 IO 缓冲：有线/扬声器路径上再省几毫秒（蓝牙路径由系统决定，忽略此值）。
            try? session.setPreferredIOBufferDuration(0.005)
            configured = true
        }
        try? session.setActive(true)
    }

    /// 比赛开始：激活会话并启动静音保活。
    func beginMatch() {
        activate()
        if keepAlive == nil, let p = try? AVAudioPlayer(data: Self.silentWAV) {
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            keepAlive = p
        }
        keepAlive?.play()
    }

    /// 比赛结束：停掉保活，释放硬件（省电）。
    func endMatch() {
        keepAlive?.stop()
        keepAlive = nil
    }

    /// 1 秒 16-bit 单声道 44.1kHz 静音 WAV（内存生成，不占资源包）。
    private static let silentWAV: Data = {
        let sampleRate = 44_100, channels = 1, seconds = 1
        let pcmBytes = sampleRate * channels * 2 * seconds
        var data = Data(capacity: 44 + pcmBytes)
        func s(_ v: String) { data.append(v.data(using: .ascii)!) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        s("RIFF"); u32(UInt32(36 + pcmBytes)); s("WAVE")
        s("fmt "); u32(16); u16(1); u16(UInt16(channels))
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * channels * 2))
        u16(UInt16(channels * 2)); u16(16)
        s("data"); u32(UInt32(pcmBytes))
        data.append(Data(count: pcmBytes))
        return data
    }()
}
