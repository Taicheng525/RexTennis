import Foundation
import SwiftUI

/// App 根状态：在「赛前设置」与「比赛进行」之间路由。
@MainActor
final class AppModel: ObservableObject {

    /// 当前进行中的比赛（nil 表示停留在赛前设置页）。
    @Published var match: MatchViewModel?

    /// 赛前设置里选择的播报语言（默认读取上次偏好）。
    @Published var language: AnnounceLanguage = SettingsStore.language

    /// 开始一场新比赛。
    func startMatch(config: MatchConfig) {
        match = MatchViewModel(config: config, language: language)
    }

    /// 结束当前比赛，回到设置页。
    func endMatch() {
        // 沿用刚才比赛里的语言选择。
        if let current = match?.language { language = current }
        match = nil
    }
}
