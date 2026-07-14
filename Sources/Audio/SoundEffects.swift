import AVFoundation

/// 真实球场氛围音效（内置真实录音，比赛中手动触发）。
/// - applause：球场轻掌声（好球礼貌鼓掌）
/// - cheer：热烈掌声 + 欢呼
/// - bigcheer：狂欢人群 + 口哨（关键分/胜利）
/// - cheers：全场人群欢呼
/// - groan：观众失望叹息（可惜的失误/被逆转）
final class SoundEffects {

    enum Kind: String, CaseIterable, Identifiable {
        case applause, cheer, bigcheer, cheers, groan
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

    /// 播放指定音效。多个音效可**同时叠加**播放、互不打断
    /// （现场掌声/欢呼/叹息本就会重叠）；不打断语音播报。
    func play(_ kind: Kind) {
        ensureSession()
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
