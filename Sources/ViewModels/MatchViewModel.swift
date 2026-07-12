import Foundation
import SwiftUI

/// 单场比赛的视图模型：串联计分引擎与语音播报，并用快照栈实现撤销。
@MainActor
final class MatchViewModel: ObservableObject {

    @Published private(set) var state: MatchState
    @Published var language: AnnounceLanguage {
        didSet {
            announcer.language = language
            SettingsStore.language = language
        }
    }

    private var history: [MatchState] = []
    private let announcer = Announcer()
    private let builder = AnnouncementBuilder()

    init(config: MatchConfig, language: AnnounceLanguage) {
        self.state = MatchState(config: config)
        self.language = language
        self.announcer.language = language
    }

    var isFinished: Bool { state.phase == .finished }
    var canUndo: Bool { !history.isEmpty }

    /// `side` 得一分：记录快照 → 更新状态 → 语音播报。
    func score(_ side: Side) {
        guard !isFinished else { return }
        history.append(state)
        var next = state
        let events = ScoreEngine.applyPoint(side, to: &next)
        state = next
        let text = builder.utterance(for: events, state: next, language: language)
        announcer.speak(text)
    }

    /// 撤销上一步得分。
    func undo() {
        guard let previous = history.popLast() else { return }
        announcer.stop()
        state = previous
        announcer.speak(builder.undoText(language))
    }

    /// 播报当前比分（供手动「再报一次」按钮使用）。
    func repeatCurrentScore() {
        let event: MatchEvent = state.phase == .tiebreak ? .tiebreakPoint : .point
        guard !isFinished else { return }
        announcer.speak(builder.utterance(for: [event], state: state, language: language))
    }

#if DEBUG
    /// 仅用于 UI 截图/预览：静默施加若干分，不触发语音、不入撤销栈。
    func debugApply(_ points: [Side]) {
        var next = state
        for side in points { ScoreEngine.applyPoint(side, to: &next) }
        state = next
    }
#endif
}
