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
    var voiceCode: String { self == .chinese ? "zh-CN" : "en-US" }
}

/// 一场比赛的赛制配置（不可变，随比赛全程固定）。
struct MatchConfig: Equatable, Codable {
    /// 目标局数：4（四局制）或 6（六局制）。胜盘需先到该局数且净胜 2 局。
    var targetGames: Int
    /// 首个发球方。
    var firstServer: Side
    /// 双方队名（用于界面显示与「拿下这一局/该谁发球」等事件播报；报分本身只报数字）。
    var nameMe: String
    var nameOpp: String

    init(targetGames: Int, firstServer: Side, nameMe: String = "我方", nameOpp: String = "对方") {
        self.targetGames = targetGames
        self.firstServer = firstServer
        self.nameMe = nameMe
        self.nameOpp = nameOpp
    }

    /// 取某一方的队名。
    func name(for side: Side) -> String { side == .me ? nameMe : nameOpp }

    static let `default` = MatchConfig(targetGames: 4, firstServer: .me)
}
