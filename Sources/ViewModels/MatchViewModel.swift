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
    @Published var umpire: UmpireVoice {
        didSet {
            announcer.umpire = umpire
            SettingsStore.umpire = umpire
        }
    }

    /// 上一分是否触发换边（界面文字提醒用，显示到下一分自动清除）。
    @Published private(set) var showChangeEnds: Bool = false

    private var history: [MatchState] = []
    private let announcer = Announcer()
    private let builder = AnnouncementBuilder()
    private let soundEffects = SoundEffects()
    private let chant = ChantSynth()

    init(config: MatchConfig, language: AnnounceLanguage, umpire: UmpireVoice = SettingsStore.umpire) {
        self.state = MatchState(config: config)
        self.language = language
        self.umpire = umpire
        self.announcer.language = language
        self.announcer.umpire = umpire
        // 预热两队的「喊名加油」，首次点击零等待
        chant.prewarm(name: config.nameMe, language: language)
        chant.prewarm(name: config.nameOpp, language: language)
    }

    var isFinished: Bool { state.phase == .finished }
    var canUndo: Bool { !history.isEmpty }

    /// `side` 得一分：记录快照 → 更新状态 → 触感 → 语音播报。
    func score(_ side: Side) {
        guard !isFinished else { return }
        history.append(state)
        var next = state
        let events = ScoreEngine.applyPoint(side, to: &next)
        withAnimation(.snappy(duration: 0.3)) { state = next }
        showChangeEnds = events.contains(.changeEnds)

        // 触感：普通分轻震，局/盘结束加重
        if next.phase == .finished {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if events.contains(where: { if case .gameWon = $0 { return true }; return false }) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let text = builder.utterance(for: events, state: next, language: language)
        announcer.speak(text)
    }

    /// 撤销上一步得分（静默，不播报）。
    func undo() {
        guard let previous = history.popLast() else { return }
        announcer.stop()
        withAnimation(.snappy(duration: 0.3)) { state = previous }
        showChangeEnds = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 播放一种欢呼音效（比赛中手动触发）。
    func cheer(_ kind: SoundEffects.Kind) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        chant.stop()
        soundEffects.play(kind)
    }

    /// 人群喊某一队的队名加油（真实欢呼垫底 + 多声部口号）。
    func cheerTeam(_ side: Side) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        chant.play(name: state.config.name(for: side), language: language)
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
        var last: [MatchEvent] = []
        for side in points { last = ScoreEngine.applyPoint(side, to: &next) }
        state = next
        showChangeEnds = last.contains(.changeEnds)
    }
#endif
}
