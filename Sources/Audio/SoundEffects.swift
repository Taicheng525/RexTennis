import AVFoundation

/// 三种真实球场氛围音效（内置真实录音，Mixkit 免费授权），比赛中手动触发。
/// - applause：球场轻掌声（好球礼貌鼓掌）
/// - cheer：热烈掌声 + 欢呼
/// - bigcheer：狂欢人群 + 口哨（关键分/胜利）
final class SoundEffects {

    enum Kind: String, CaseIterable, Identifiable {
        case applause, cheer, bigcheer
        var id: String { rawValue }

        fileprivate var fileName: String { rawValue }
    }

    private var players: [Kind: AVAudioPlayer] = [:]

    init() {
        // 预加载，首次点击零延迟
        for kind in Kind.allCases {
            guard let url = Bundle.main.url(forResource: kind.fileName,
                                            withExtension: "m4a") else { continue }
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[kind] = player
            }
        }
    }

    /// 播放指定音效（打断其他音效，避免叠加过响；不打断语音播报）。
    func play(_ kind: Kind) {
        ensureSession()
        for (k, p) in players where k != kind && p.isPlaying {
            p.stop()
            p.currentTime = 0
        }
        guard let player = players[kind] else { return }
        player.currentTime = 0
        player.play()
    }

    private func ensureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }
}
