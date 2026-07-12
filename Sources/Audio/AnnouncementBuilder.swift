import Foundation

/// 把计分事件 + 当前状态转成一句中/英文播报文案（纯逻辑，可单测）。
///
/// 约定：报分时**发球方分数在前**（网球惯例）。
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
            return scoreLinePlaying(s, lang)

        case .deuce:
            return zh ? "平分，金球点" : "Deuce, sudden death point"

        case .gameWon(let side):
            if zh {
                return "\(name(side, lang))拿下这一局，局分我方\(s.gamesMe)，对方\(s.gamesOpp)"
            } else {
                return "Game, \(name(side, lang)). Games, you \(s.gamesMe), opponent \(s.gamesOpp)"
            }

        case .tiebreakStarted:
            return zh ? "进入抢七" : "Tie-break"

        case .tiebreakPoint:
            return scoreLineTiebreak(s, lang)

        case .changeEnds:
            return zh ? "换边" : "Change ends"

        case .serveChange(let side):
            return zh ? "该\(name(side, lang))发球" : "\(name(side, lang)) to serve"

        case .setWon(let side):
            let wg = s.games(for: side)
            let lg = s.games(for: side.other)
            if zh {
                return "\(name(side, lang))以\(wg)比\(lg)拿下本盘，比赛结束"
            } else {
                return "Game, set and match, \(name(side, lang)). \(wg) games to \(lg)"
            }
        }
    }

    // MARK: - 比分行（发球方在前）

    private func scoreLinePlaying(_ s: MatchState, _ lang: AnnounceLanguage) -> String {
        let server = s.server
        let receiver = server.other
        let sv = pointWord(s.gameScoreLabel(for: server), lang)
        let rv = pointWord(s.gameScoreLabel(for: receiver), lang)
        return scoreLine(server: server, sv: sv, receiver: receiver, rv: rv, lang: lang)
    }

    private func scoreLineTiebreak(_ s: MatchState, _ lang: AnnounceLanguage) -> String {
        let server = s.server
        let receiver = server.other
        let sv = String(s.tiebreakPoints(for: server))
        let rv = String(s.tiebreakPoints(for: receiver))
        return scoreLine(server: server, sv: sv, receiver: receiver, rv: rv, lang: lang)
    }

    private func scoreLine(server: Side, sv: String, receiver: Side, rv: String, lang: AnnounceLanguage) -> String {
        if lang == .chinese {
            return "\(name(server, lang))\(sv)，\(name(receiver, lang))\(rv)"
        } else {
            return "\(name(server, lang)) \(sv), \(name(receiver, lang)) \(rv)"
        }
    }

    // MARK: - 词汇

    private func name(_ side: Side, _ lang: AnnounceLanguage) -> String {
        switch (side, lang) {
        case (.me, .chinese): return "我方"
        case (.opponent, .chinese): return "对方"
        case (.me, .english): return "You"
        case (.opponent, .english): return "Opponent"
        }
    }

    /// 英文把 0/15/30/40 读成 love/fifteen/thirty/forty；中文保留数字（TTS 直接读中文数）。
    private func pointWord(_ label: String, _ lang: AnnounceLanguage) -> String {
        guard lang == .english else { return label }
        switch label {
        case "0": return "love"
        case "15": return "fifteen"
        case "30": return "thirty"
        case "40": return "forty"
        default: return label
        }
    }
}
