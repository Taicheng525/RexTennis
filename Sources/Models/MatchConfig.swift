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
    /// 每队名字（1-2 个）：单打 1 个，双打 2 个。第 1 个可写球员名，也可直接写队名。
    /// 报分只报数字；名字用于界面显示与「拿下这一局/该谁发球」等事件播报。
    var playersMe: [String]
    var playersOpp: [String]

    init(targetGames: Int, firstServer: Side,
         playersMe: [String] = ["我方"], playersOpp: [String] = ["对方"]) {
        self.targetGames = targetGames
        self.firstServer = firstServer
        self.playersMe = playersMe.isEmpty ? ["我方"] : playersMe
        self.playersOpp = playersOpp.isEmpty ? ["对方"] : playersOpp
    }

    /// 某一方的名字数组。
    func players(for side: Side) -> [String] { side == .me ? playersMe : playersOpp }

    /// 界面显示名：双打用「甲 / 乙」。
    func name(for side: Side) -> String { players(for: side).joined(separator: " / ") }

    /// 是否双打（任一方 2 人）。
    var isDoubles: Bool { playersMe.count > 1 || playersOpp.count > 1 }

    static let `default` = MatchConfig(targetGames: 4, firstServer: .me)
}
