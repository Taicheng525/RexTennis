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

    static let `default` = MatchConfig(targetGames: 4, firstServer: .me)
}
