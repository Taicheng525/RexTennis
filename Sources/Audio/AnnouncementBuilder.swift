import Foundation

/// 把计分事件 + 当前状态转成一句中/英文播报文案（纯逻辑，可单测）。
///
/// 播报约定（专业裁判风格）：
/// - **报分只报数字，不带队名**，且**发球方分数永远在前**。
/// - 0 的读法：英文 love（抢七读 zero），中文 零。
/// - 双方同分：中文「十五平」，英文 "fifteen all"。
/// - 队名只出现在事件播报里：拿下一局 / 该谁发球 / 胜盘。
struct AnnouncementBuilder {

    /// 生成一次得分后的完整播报文案。events 为空则返回空串。
    func utterance(for events: [MatchEvent], state: MatchState, language: AnnounceLanguage) -> String {
        let phrases = events.compactMap { phrase(for: $0, state: state, language: language) }
        return phrases.joined(separator: language == .chinese ? "。" : ". ")
    }

    /// 撤销时的提示语。
    func undoText(_ language: AnnounceLanguage) -> String {
        language == .chinese ? "已撤销" : "Undo"
    }

    // MARK: - 单事件文案

    private func phrase(for event: MatchEvent, state s: MatchState, language lang: AnnounceLanguage) -> String? {
        let zh = lang == .chinese
        switch event {
        case .point:
            return gameScoreCall(s, lang)

        case .deuce:
            return zh ? "平分，金球" : "Deuce, deciding point"

        case .gameWon(let side):
            let name = s.config.name(for: side)
            let wg = s.games(for: side)
            let lg = s.games(for: side.other)
            if zh {
                return "\(name)拿下这一局，局分\(wg)比\(lg)"
            } else {
                return "Game, \(name). Games \(wg) \(lg)"
            }

        case .tiebreakStarted:
            return zh ? "进入抢七" : "Tie-break"

        case .tiebreakPoint:
            return tiebreakScoreCall(s, lang)

        case .changeEnds:
            return nil   // 换边只做界面文字提醒，不语音播报

        case .serveChange(let side):
            let name = s.config.name(for: side)
            return zh ? "该\(name)发球" : "\(name) to serve"

        case .setWon(let side):
            let name = s.config.name(for: side)
            let wg = s.games(for: side)
            let lg = s.games(for: side.other)
            if zh {
                return "\(name)以\(wg)比\(lg)拿下本盘，比赛结束"
            } else {
                return "Game, set and match, \(name). \(wg) games to \(lg)"
            }
        }
    }

    // MARK: - 报分（发球方在前，只报数字）

    /// 常规局报分：0/15/30/40，中文数词、英文 love/fifteen/thirty/forty。
    private func gameScoreCall(_ s: MatchState, _ lang: AnnounceLanguage) -> String {
        let sv = min(s.server == .me ? s.pointsMe : s.pointsOpp, 3)
        let rv = min(s.server == .me ? s.pointsOpp : s.pointsMe, 3)

        if lang == .chinese {
            let words = ["零", "十五", "三十", "四十"]
            return sv == rv ? "\(words[sv])平" : "\(words[sv])比\(words[rv])"
        } else {
            let words = ["love", "fifteen", "thirty", "forty"]
            return sv == rv ? "\(words[sv]) all" : "\(words[sv]) \(words[rv])"
        }
    }

    /// 抢七报分：纯数字，发球方在前；0 中文读零、英文读 zero。
    private func tiebreakScoreCall(_ s: MatchState, _ lang: AnnounceLanguage) -> String {
        let sv = s.tiebreakPoints(for: s.server)
        let rv = s.tiebreakPoints(for: s.server.other)

        if lang == .chinese {
            return sv == rv ? "\(zhNumber(sv))平" : "\(zhNumber(sv))比\(zhNumber(rv))"
        } else {
            return sv == rv ? "\(enNumber(sv)) all" : "\(enNumber(sv)) \(enNumber(rv))"
        }
    }

    /// 中文数字：0 显式写「零」，其余交给 TTS 按中文读数字。
    private func zhNumber(_ n: Int) -> String { n == 0 ? "零" : String(n) }

    /// 英文数字：0 显式写 "zero"（抢七惯例），其余 TTS 正常读数字。
    private func enNumber(_ n: Int) -> String { n == 0 ? "zero" : String(n) }
}
