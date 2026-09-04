import Foundation

/// 把计分事件 + 当前状态转成一句中/英文播报文案（纯逻辑，可单测）。
///
/// 播报约定（专业裁判风格）：
/// - **报分只报数字，不带队名**，且**发球方分数永远在前**。
/// - 0 的读法：英文 love（抢七读 zero），中文 零。
/// - 双方同分：中文「十五平」，英文 "fifteen all"。
/// - 队名只在「发球」播报时出现（英文播报里嵌中文队名会卡顿，故局末/胜盘只报队员名）。
///
/// 每个短句都是一个 `Phrase`：既能生成文本（系统 TTS 用），也能给出**内置音频的
/// 片段 ID**（`clipID`）。带人名/队名的短句没有片段 ID；`nameless` 模式下改用
/// 「我方 / 对方」措辞，所有短句都可用内置音频播放。
struct AnnouncementBuilder {

    // MARK: - 短句

    enum Phrase: Equatable {
        /// 常规局比分（发球方在前，0…3 → 零/15/30/40）
        case score(server: Int, receiver: Int)
        case deuce
        /// 拿下一局：赢家名（nil = 用「我方/对方」）+ 局分（赢家在前）
        case gameWon(side: Side, name: String?, won: Int, lost: Int)
        case tiebreakStarted
        /// 抢七比分（发球方在前）
        case tiebreakScore(server: Int, receiver: Int)
        case changeEnds
        /// 发球方变更：名字（nil = 用「我方/对方」）
        case serve(side: Side, name: String?)
        /// 胜盘：赢家名（nil = 「我方/对方」）+ 局分 + 是否抢七决出
        case setWon(side: Side, name: String?, won: Int, lost: Int, tiebreak: Bool)
        /// 裁判喊话
        case call(UmpireCall)

        /// 内置音频片段 ID（稳定、可做文件名）。含具体人名的短句返回 nil。
        var clipID: String? {
            switch self {
            case .score(let s, let r):            return "score_\(s)_\(r)"
            case .deuce:                          return "deuce"
            case .gameWon(let side, let name, let w, let l):
                return name == nil ? "game_\(side.rawValue)_\(w)_\(l)" : nil
            case .tiebreakStarted:                return "tb_start"
            case .tiebreakScore(let s, let r):
                // 内置音频只覆盖 0…12；更长的抢七退回系统 TTS
                return (s <= 12 && r <= 12) ? "tb_\(s)_\(r)" : nil
            case .changeEnds:                     return "change_ends"
            case .serve(let side, let name):      return name == nil ? "serve_\(side.rawValue)" : nil
            case .setWon(let side, let name, let w, let l, let tb):
                return name == nil ? "set\(tb ? "tb" : "")_\(side.rawValue)_\(w)_\(l)" : nil
            case .call(let c):                    return "call_\(c.rawValue)"
            }
        }

        /// 短句文本。
        func text(_ lang: AnnounceLanguage) -> String {
            let zh = lang == .chinese
            switch self {
            case .score(let sv, let rv):
                if zh {
                    let words = ["零", "十五", "三十", "四十"]
                    return sv == rv ? "\(words[sv])平" : "\(words[sv])比\(words[rv])"
                } else {
                    let words = ["love", "fifteen", "thirty", "forty"]
                    return sv == rv ? "\(words[sv]) all" : "\(words[sv]) \(words[rv])"
                }

            case .deuce:
                return zh ? "平分，金球" : "Deuce, deciding point"

            case .gameWon(let side, let name, let wg, let lg):
                if let name {
                    return zh ? "\(name)拿下这一局，局分\(wg)比\(lg)"
                              : "Game, \(name). Games \(wg) \(lg)"
                }
                return zh ? "\(Self.sideWord(side, zh: true))拿下这一局，局分\(wg)比\(lg)"
                          : "Game to \(Self.sideWord(side, zh: false)). Games \(wg) \(lg)"

            case .tiebreakStarted:
                return zh ? "进入抢七" : "Tie-break"

            case .tiebreakScore(let sv, let rv):
                if zh {
                    return sv == rv ? "\(Self.zhNumber(sv))平" : "\(Self.zhNumber(sv))比\(Self.zhNumber(rv))"
                } else {
                    return sv == rv ? "\(Self.enNumber(sv)) all" : "\(Self.enNumber(sv)) \(Self.enNumber(rv))"
                }

            case .changeEnds:
                return zh ? "换边" : "Change ends"   // 简洁语音 + 界面文字双提示

            case .serve(let side, let name):
                if let name { return zh ? "该\(name)发球" : "\(name) to serve" }
                return zh ? "该\(Self.sideWord(side, zh: true))发球"
                          : (side == .me ? "Our serve" : "Their serve")

            case .setWon(let side, let name, let wg, let lg, let tb):
                let who = name ?? Self.sideWord(side, zh: zh)
                if zh {
                    return tb
                        ? "\(who)以\(wg)比\(lg)抢七拿下本盘，比赛结束"
                        : "\(who)以\(wg)比\(lg)拿下本盘，比赛结束"
                }
                let head = name != nil ? "Game, set and match, \(who)" : "Game, set and match to \(who)"
                return tb
                    ? "\(head). \(wg) games to \(lg), on the tie-break"
                    : "\(head). \(wg) games to \(lg)"

            case .call(let call):
                switch call {
                case .quiet:     return zh ? "请大家保持安静，谢谢" : "Ladies and gentlemen, quiet please. Thank you"
                case .out:       return zh ? "出界"       : "Out!"
                case .letFirst:  return zh ? "擦网，重发一发" : "Let. First service"
                case .letSecond: return zh ? "擦网，重发二发" : "Let. Second service"
                }
            }
        }

        private static func sideWord(_ side: Side, zh: Bool) -> String {
            zh ? (side == .me ? "我方" : "对方") : (side == .me ? "us" : "them")
        }
        /// 中文数字：0 显式写「零」，其余交给 TTS 按中文读数字。
        private static func zhNumber(_ n: Int) -> String { n == 0 ? "零" : String(n) }
        /// 英文数字：0 显式写 "zero"（抢七惯例），其余 TTS 正常读数字。
        private static func enNumber(_ n: Int) -> String { n == 0 ? "zero" : String(n) }
    }

    /// 手动触发的裁判喊话（非计分事件），走和报分同一个裁判声线播报。
    enum UmpireCall: String, CaseIterable, Identifiable {
        case quiet, out, letFirst, letSecond
        var id: String { rawValue }
    }

    // MARK: - 对外

    /// 一次得分后的短句序列。`nameless=true` 时不带人名/队名（内置音频模式）。
    func phrases(for events: [MatchEvent], state: MatchState, language: AnnounceLanguage,
                 nameless: Bool = false) -> [Phrase] {
        events.compactMap { phrase(for: $0, state: state, language: language, nameless: nameless) }
    }

    /// 生成一次得分后的完整播报文案。events 为空则返回空串。
    func utterance(for events: [MatchEvent], state: MatchState, language: AnnounceLanguage,
                   nameless: Bool = false) -> String {
        join(phrases(for: events, state: state, language: language, nameless: nameless), language)
    }

    /// 把短句拼成一句话。
    func join(_ phrases: [Phrase], _ language: AnnounceLanguage) -> String {
        phrases.map { $0.text(language) }.joined(separator: language == .chinese ? "。" : ". ")
    }

    /// 撤销时的提示语。
    func undoText(_ language: AnnounceLanguage) -> String {
        language == .chinese ? "已撤销" : "Undo"
    }

    func umpireCall(_ call: UmpireCall, language: AnnounceLanguage) -> String {
        Phrase.call(call).text(language)
    }

    // MARK: - 单事件 → 短句

    private func phrase(for event: MatchEvent, state s: MatchState, language lang: AnnounceLanguage,
                        nameless: Bool) -> Phrase? {
        switch event {
        case .point:
            let sv = min(s.server == .me ? s.pointsMe : s.pointsOpp, 3)
            let rv = min(s.server == .me ? s.pointsOpp : s.pointsMe, 3)
            return .score(server: sv, receiver: rv)
        case .deuce:
            return .deuce
        case .gameWon(let side):
            return .gameWon(side: side, name: nameless ? nil : spokenName(s, side, lang),
                            won: s.games(for: side), lost: s.games(for: side.other))
        case .tiebreakStarted:
            return .tiebreakStarted
        case .tiebreakPoint:
            return .tiebreakScore(server: s.tiebreakPoints(for: s.server),
                                  receiver: s.tiebreakPoints(for: s.server.other))
        case .changeEnds:
            return .changeEnds
        case .serveChange(let side):
            return .serve(side: side, name: nameless ? nil : serverSpokenName(s, side, lang))
        case .setWon(let side):
            return .setWon(side: side, name: nameless ? nil : spokenName(s, side, lang),
                           won: s.games(for: side), lost: s.games(for: side.other),
                           tiebreak: s.finishedByTiebreak)
        }
    }

    /// 局末/胜盘播报名：**只报队员名**（不报队名——队名只在发球时报，避免英文播报里
    /// 嵌中文队名造成卡顿/多余停顿）。双打两名队员按语言连接（中文「、」、英文「and」）。
    private func spokenName(_ s: MatchState, _ side: Side, _ lang: AnnounceLanguage) -> String {
        let players = s.config.players(for: side)
        guard players.count > 1 else { return players.first ?? "" }
        return players.joined(separator: lang == .chinese ? "、" : " and ")
    }

    /// 发球播报名：队名（若有）+ 该队**全部**队员名。双打报两人——具体谁发球双打可随时换，
    /// 硬报单人会出错；单打即本人。
    private func serverSpokenName(_ s: MatchState, _ side: Side, _ lang: AnnounceLanguage) -> String {
        let names = spokenName(s, side, lang)
        let tn = s.config.teamName(for: side)
        if tn.isEmpty { return names }
        return lang == .chinese ? "\(tn)，\(names)" : "\(tn), \(names)"
    }

    // MARK: - 内置音频清单

    /// 内置音频需要覆盖的全部短句（与 `clipID` 一一对应）。生成脚本据此产出音频文件。
    static var allClipPhrases: [Phrase] {
        var list: [Phrase] = []
        for s in 0...3 { for r in 0...3 { list.append(.score(server: s, receiver: r)) } }
        list.append(.deuce)
        for side in [Side.me, .opponent] {
            for w in 1...7 { for l in 0...7 { list.append(.gameWon(side: side, name: nil, won: w, lost: l)) } }
        }
        list.append(.tiebreakStarted)
        for s in 0...12 { for r in 0...12 { list.append(.tiebreakScore(server: s, receiver: r)) } }
        list.append(.changeEnds)
        for side in [Side.me, .opponent] { list.append(.serve(side: side, name: nil)) }
        // 胜盘局分：4 局制 4-0/4-1/4-2/5-3、抢七 5-4；6 局制 6-0…6-4/7-5、抢七 7-6
        let plain = [(4,0),(4,1),(4,2),(5,3),(6,0),(6,1),(6,2),(6,3),(6,4),(7,5)]
        let tb = [(5,4),(7,6)]
        for side in [Side.me, .opponent] {
            for (w, l) in plain { list.append(.setWon(side: side, name: nil, won: w, lost: l, tiebreak: false)) }
            for (w, l) in tb { list.append(.setWon(side: side, name: nil, won: w, lost: l, tiebreak: true)) }
        }
        for c in UmpireCall.allCases { list.append(.call(c)) }
        return list
    }
}
