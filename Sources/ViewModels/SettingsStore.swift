import Foundation

/// 轻量偏好存储：记住播报语言、裁判声音、队名（离线单场比赛不做历史持久化）。
enum SettingsStore {
    private static let languageKey = "rex.announceLanguage"
    private static let umpireKey = "rex.umpireVoice"
    private static let playersMeKey = "rex.playersMe"
    private static let playersOppKey = "rex.playersOpp"
    private static let teamNameMeKey = "rex.teamNameMe"
    private static let teamNameOppKey = "rex.teamNameOpp"
    private static let doublesKey = "rex.isDoubles"
    private static let playerRosterKey = "rex.playerRoster"
    private static let teamRosterKey = "rex.teamRoster"

    static var language: AnnounceLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: languageKey) ?? ""
            return AnnounceLanguage(rawValue: raw) ?? .chinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
        }
    }

    static var umpire: UmpireVoice {
        get {
            let raw = UserDefaults.standard.string(forKey: umpireKey) ?? ""
            return UmpireVoice(rawValue: raw) ?? .female
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: umpireKey)
        }
    }

    static var playersMe: [String] {
        get { UserDefaults.standard.stringArray(forKey: playersMeKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: playersMeKey) }
    }

    static var playersOpp: [String] {
        get { UserDefaults.standard.stringArray(forKey: playersOppKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: playersOppKey) }
    }

    static var teamNameMe: String {
        get { UserDefaults.standard.string(forKey: teamNameMeKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: teamNameMeKey) }
    }
    static var teamNameOpp: String {
        get { UserDefaults.standard.string(forKey: teamNameOppKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: teamNameOppKey) }
    }
    static var isDoubles: Bool {
        get { UserDefaults.standard.bool(forKey: doublesKey) }
        set { UserDefaults.standard.set(newValue, forKey: doublesKey) }
    }

    // MARK: - 名单（预存队员名 / 队名，下次可直接选择）

    static var playerRoster: [String] {
        get { UserDefaults.standard.stringArray(forKey: playerRosterKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: playerRosterKey) }
    }
    static var teamRoster: [String] {
        get { UserDefaults.standard.stringArray(forKey: teamRosterKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: teamRosterKey) }
    }

    /// 记住用到的队员名（去重、最近在前、上限 40），供下次直接选择。
    static func remember(players: [String]) { playerRoster = merged(players, into: playerRoster) }
    /// 记住用到的队名。
    static func remember(teams: [String]) { teamRoster = merged(teams, into: teamRoster) }

    private static func merged(_ new: [String], into list: [String]) -> [String] {
        var r = list
        for n in new.reversed() where !n.isEmpty {
            r.removeAll { $0 == n }
            r.insert(n, at: 0)
        }
        return Array(r.prefix(40))
    }
}
