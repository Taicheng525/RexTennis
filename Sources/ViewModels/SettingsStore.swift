import Foundation

/// 轻量偏好存储：记住播报语言、裁判声音、队名（离线单场比赛不做历史持久化）。
enum SettingsStore {
    private static let languageKey = "rex.announceLanguage"
    private static let umpireKey = "rex.umpireVoice"
    private static let nameMeKey = "rex.nameMe"
    private static let nameOppKey = "rex.nameOpp"

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

    static var nameMe: String {
        get { UserDefaults.standard.string(forKey: nameMeKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameMeKey) }
    }

    static var nameOpp: String {
        get { UserDefaults.standard.string(forKey: nameOppKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameOppKey) }
    }
}
