import Foundation

/// 比赛所处阶段。
enum MatchPhase: String, Equatable, Codable {
    case playing    // 常规局进行中
    case tiebreak   // 抢七进行中
    case finished   // 比赛已结束
}

/// 比赛的完整状态。纯值类型：可整体拷贝，用于撤销快照。
struct MatchState: Equatable, Codable {
    let config: MatchConfig

    // 当前这一局的原始得分计数（0/1/2/3 -> 0/15/30/40；无广告制先到 4 分胜局）
    var pointsMe: Int = 0
    var pointsOpp: Int = 0

    // 本盘局分
    var gamesMe: Int = 0
    var gamesOpp: Int = 0

    // 抢七得分
    var tbMe: Int = 0
    var tbOpp: Int = 0

    /// 即将发球（下一分）的一方。常规局内保持不变；抢七内每分自动更新。
    var server: Side

    /// 抢七首发方（决定抢七内的 1-2-2-2 轮换）。
    var tiebreakStarter: Side?

    var phase: MatchPhase = .playing
    var winner: Side?

    init(config: MatchConfig) {
        self.config = config
        self.server = config.firstServer
    }
}

// MARK: - 展示辅助

extension MatchState {
    /// 是否处于平分（金球点）：常规局双方均到 40。
    var isDeuce: Bool { phase == .playing && pointsMe == 3 && pointsOpp == 3 }

    /// 某一方当前这一局要展示的分数文案（0/15/30/40 或抢七的数字）。
    func gameScoreLabel(for side: Side) -> String {
        switch phase {
        case .tiebreak:
            return String(side == .me ? tbMe : tbOpp)
        case .playing:
            let n = side == .me ? pointsMe : pointsOpp
            return MatchState.pointLabels[min(n, 3)]
        case .finished:
            return "-"
        }
    }

    /// 某一方本盘已赢局数。
    func games(for side: Side) -> Int { side == .me ? gamesMe : gamesOpp }

    /// 某一方抢七得分。
    func tiebreakPoints(for side: Side) -> Int { side == .me ? tbMe : tbOpp }

    static let pointLabels = ["0", "15", "30", "40"]
}
