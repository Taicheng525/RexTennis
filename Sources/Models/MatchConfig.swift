import Foundation

/// 比赛中的一方。`me` = 我方，`opponent` = 对方。
enum Side: String, Equatable, Codable {
    case me
    case opponent

    /// 对手方
    var other: Side { self == .me ? .opponent : .me }
}

/// 播报语言。
enum AnnounceLanguage: String, Equatable, Codable, CaseIterable {
    case chinese
    case english

    /// AVSpeechSynthesisVoice 使用的 BCP-47 语言代码。
    /// 英文用英式（en-GB），贴近温网裁判口音。
    var voiceCode: String { self == .chinese ? "zh-CN" : "en-GB" }
}

/// 裁判声音（性别可选，仿温网裁判风格）。
enum UmpireVoice: String, Equatable, Codable, CaseIterable {
    case female
    case male
}

/// 一场比赛的赛制配置（不可变，随比赛全程固定）。
struct MatchConfig: Equatable, Codable {
    /// 目标局数：4（四局制）或 6（六局制）。胜盘需先到该局数且净胜 2 局。
    var targetGames: Int
    /// 首个发球方。
    var firstServer: Side
    /// 双打时首发队伍中**先发球的队员索引**（0 = 队员 1，1 = 队员 2）；单打无意义（恒 0）。
    var firstServerPlayer: Int
    /// 队名（选填，与队员名相互独立）。非空时作为该队的显示/播报名。
    var teamNameMe: String
    var teamNameOpp: String
    /// 队员名：单打 1 个、双打 2 个。报分只报数字；名字用于显示与事件播报。
    var playersMe: [String]
    var playersOpp: [String]

    init(targetGames: Int, firstServer: Side, firstServerPlayer: Int = 0,
         teamNameMe: String = "", teamNameOpp: String = "",
         playersMe: [String] = ["我方"], playersOpp: [String] = ["对方"]) {
        self.targetGames = targetGames
        self.firstServer = firstServer
        self.firstServerPlayer = firstServerPlayer
        self.teamNameMe = teamNameMe
        self.teamNameOpp = teamNameOpp
        self.playersMe = playersMe.isEmpty ? ["我方"] : playersMe
        self.playersOpp = playersOpp.isEmpty ? ["对方"] : playersOpp
    }

    /// 某一方的队员名数组。
    func players(for side: Side) -> [String] { side == .me ? playersMe : playersOpp }
    /// 某一方的队名（可能为空）。
    func teamName(for side: Side) -> String { side == .me ? teamNameMe : teamNameOpp }

    /// 显示/播报名：有队名用队名，否则用队员名（双打「甲 / 乙」）。
    func name(for side: Side) -> String {
        let tn = teamName(for: side)
        return tn.isEmpty ? players(for: side).joined(separator: " / ") : tn
    }

    /// 是否双打（任一方 2 人）。
    var isDoubles: Bool { playersMe.count > 1 || playersOpp.count > 1 }

    static let `default` = MatchConfig(targetGames: 4, firstServer: .me)
}
