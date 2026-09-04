import AVFoundation

/// 真实球场氛围音效（内置真实录音，比赛中手动触发）。
/// - applause：球场轻掌声（好球礼貌鼓掌）
/// - cheer：热烈掌声 + 欢呼
/// - bigcheer：狂欢人群 + 口哨（关键分/胜利）
/// - cheers：全场人群欢呼
/// - groan：观众失望叹息（可惜的失误/被逆转）
///
/// 音频会话由 `AudioSessionManager` 统一管理（比赛开始即激活并保活），
/// 这里**不再**每次播放都重设会话——那会触发路由重配置、点击后要等一下才出声。
final class SoundEffects {

    enum Kind: String, CaseIterable, Identifiable {
        case applause, cheer, bigcheer, cheers, groan
        var id: String { rawValue }

        fileprivate var fileName: String { rawValue }
    }

    private var players: [Kind: AVAudioPlayer] = [:]

    init() {
        // 预加载 + 预备缓冲，首次点击即出声
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
        guard let player = players[kind] else { return }
        player.currentTime = 0
        player.play()
    }

    /// 立即停掉所有正在播放的音效（配合「全部静音」）。
    /// stop() 会释放解码缓冲，随手 prepareToPlay 让下一次点击仍然零延迟。
    func stopAll() {
        for (_, p) in players where p.isPlaying {
            p.stop()
            p.currentTime = 0
            p.prepareToPlay()
        }
    }
}
