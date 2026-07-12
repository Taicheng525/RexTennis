import Foundation

/// 轻量偏好存储：仅记住播报语言（离线单场比赛不做历史持久化）。
enum SettingsStore {
    private static let languageKey = "rex.announceLanguage"

    static var language: AnnounceLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: languageKey) ?? ""
            return AnnounceLanguage(rawValue: raw) ?? .chinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
        }
    }
}
