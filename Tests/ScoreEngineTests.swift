import XCTest
@testable import RexTennis

final class ScoreEngineTests: XCTestCase {

    // MARK: - 辅助

    private func makeState(target: Int = 4, server: Side = .me) -> MatchState {
        MatchState(config: MatchConfig(targetGames: target, firstServer: server))
    }

    /// 让 `side` 以 4-0 拿下当前这一局（从 0-0 开始），返回制胜那一分的事件。
    @discardableResult
    private func winGame(_ side: Side, _ s: inout MatchState) -> [MatchEvent] {
        var last: [MatchEvent] = []
        for _ in 0..<4 { last = ScoreEngine.applyPoint(side, to: &s) }
        return last
    }

    /// 交替赢局，把常规盘推进到 N-N 从而进入抢七。
    private func stateInTiebreak(target: Int = 4, server: Side = .me) -> MatchState {
        var s = makeState(target: target, server: server)
        for _ in 0..<target {
            winGame(.me, &s)
            winGame(.opponent, &s)
        }
        return s
    }

    // MARK: - 局内 & 金球

    func testPointLabels() {
        var s = makeState()
        XCTAssertEqual(s.gameScoreLabel(for: .me), "0")
        ScoreEngine.applyPoint(.me, to: &s); XCTAssertEqual(s.gameScoreLabel(for: .me), "15")
        ScoreEngine.applyPoint(.me, to: &s); XCTAssertEqual(s.gameScoreLabel(for: .me), "30")
        ScoreEngine.applyPoint(.me, to: &s); XCTAssertEqual(s.gameScoreLabel(for: .me), "40")
    }

    func testLoveGame() {
        var s = makeState()
        let e = winGame(.me, &s)
        XCTAssertTrue(e.contains(.gameWon(.me)))
        XCTAssertEqual(s.gamesMe, 1)
        XCTAssertEqual(s.pointsMe, 0)   // 局内比分已重置
    }

    func testDeuceThenGoldenPoint() {
        var s = makeState()
        // 打到 3-3 平分
        for _ in 0..<3 {
            ScoreEngine.applyPoint(.me, to: &s)
            ScoreEngine.applyPoint(.opponent, to: &s)
        }
        XCTAssertTrue(s.isDeuce)

        // 金球分：下一分直接定局
        let e = ScoreEngine.applyPoint(.me, to: &s)
        XCTAssertTrue(e.contains(.gameWon(.me)))
        XCTAssertEqual(s.gamesMe, 1)
        XCTAssertFalse(s.isDeuce)
    }

    // MARK: - 4 局制盘

    func test4Game_winAt4_0() {
        var s = makeState(target: 4)
        for _ in 0..<3 { winGame(.me, &s) }          // 3-0
        let e = winGame(.me, &s)                     // 4-0
        XCTAssertTrue(e.contains(.setWon(.me)))
        XCTAssertEqual(s.phase, .finished)
        XCTAssertEqual(s.winner, .me)
        XCTAssertEqual(s.gamesMe, 4)
    }

    func test4Game_winAt5_3() {
        var s = makeState(target: 4)
        for _ in 0..<3 { winGame(.me, &s); winGame(.opponent, &s) }   // 3-3
        XCTAssertEqual(s.phase, .playing)

        let e43 = winGame(.me, &s)                   // 4-3：需净胜 2，未结束
        XCTAssertFalse(e43.contains(.setWon(.me)))
        XCTAssertEqual(s.phase, .playing)

        let e53 = winGame(.me, &s)                   // 5-3：净胜 2，胜盘
        XCTAssertTrue(e53.contains(.setWon(.me)))
        XCTAssertEqual(s.gamesMe, 5)
        XCTAssertEqual(s.gamesOpp, 3)
    }

    func test4Game_tiebreakAt4_4() {
        var s = makeState(target: 4)
        for _ in 0..<4 { winGame(.me, &s); winGame(.opponent, &s) }
        XCTAssertEqual(s.phase, .tiebreak)
        XCTAssertEqual(s.gamesMe, 4)
        XCTAssertEqual(s.gamesOpp, 4)
        XCTAssertNotNil(s.tiebreakStarter)
        XCTAssertEqual(s.server, s.tiebreakStarter)
    }

    // MARK: - 6 局制盘

    func test6Game_winAt7_5() {
        var s = makeState(target: 6)
        for _ in 0..<5 { winGame(.me, &s); winGame(.opponent, &s) }   // 5-5
        let e65 = winGame(.me, &s)                   // 6-5：未结束
        XCTAssertFalse(e65.contains(.setWon(.me)))
        XCTAssertEqual(s.phase, .playing)
        let e75 = winGame(.me, &s)                   // 7-5：胜盘
        XCTAssertTrue(e75.contains(.setWon(.me)))
        XCTAssertEqual(s.gamesMe, 7)
    }

    func test6Game_tiebreakAt6_6() {
        var s = makeState(target: 6)
        for _ in 0..<6 { winGame(.me, &s); winGame(.opponent, &s) }
        XCTAssertEqual(s.phase, .tiebreak)
        XCTAssertEqual(s.gamesMe, 6)
        XCTAssertEqual(s.gamesOpp, 6)
    }

    // MARK: - 抢七

    func testTiebreak_winTo7() {
        var s = stateInTiebreak(target: 4)
        for _ in 0..<7 { ScoreEngine.applyPoint(.me, to: &s) }
        XCTAssertEqual(s.phase, .finished)
        XCTAssertEqual(s.winner, .me)
        XCTAssertEqual(s.gamesMe, 5)     // N+1 : N
        XCTAssertEqual(s.gamesOpp, 4)
        XCTAssertTrue(s.finishedByTiebreak)
    }

    func testNonTiebreakWinNotFlagged() {
        var s = makeState(target: 4)
        for _ in 0..<4 { winGame(.me, &s) }   // 4-0 直接胜盘
        XCTAssertEqual(s.phase, .finished)
        XCTAssertFalse(s.finishedByTiebreak)
    }

    func testTiebreak_needsMarginOfTwo() {
        var s = stateInTiebreak(target: 4)
        for _ in 0..<6 {                              // 6-6
            ScoreEngine.applyPoint(.me, to: &s)
            ScoreEngine.applyPoint(.opponent, to: &s)
        }
        XCTAssertEqual(s.phase, .tiebreak)
        ScoreEngine.applyPoint(.me, to: &s)          // 7-6：未结束
        XCTAssertEqual(s.phase, .tiebreak)
        ScoreEngine.applyPoint(.me, to: &s)          // 8-6：胜盘
        XCTAssertEqual(s.phase, .finished)
        XCTAssertEqual(s.winner, .me)
        XCTAssertEqual(s.gamesMe, 5)
    }

    func testTiebreak_changeEndsEverySixPoints() {
        var s = stateInTiebreak(target: 4)
        var last: [MatchEvent] = []
        for _ in 0..<3 {                              // 累计 6 分
            last = ScoreEngine.applyPoint(.me, to: &s)
            last = ScoreEngine.applyPoint(.opponent, to: &s)
        }
        XCTAssertTrue(last.contains(.changeEnds))
    }

    func testTiebreakServeRotation() {
        // 1-2-2-2：starter 发第 1 分，其后每 2 分换发球。
        let starter = Side.me
        let expected: [Side] = [.me, .opponent, .opponent, .me, .me, .opponent, .opponent]
        for played in 0..<expected.count {
            XCTAssertEqual(ScoreEngine.tiebreakServer(played: played, starter: starter),
                           expected[played], "played=\(played)")
        }
    }

    // MARK: - 换边 & 发球轮换（常规局）

    func testChangeEndsOnOddGames() {
        var s = makeState(target: 6, server: .me)
        let g1 = winGame(.me, &s)        // 总局数 1（奇）→ 换边
        XCTAssertTrue(g1.contains(.changeEnds))
        XCTAssertEqual(s.server, .opponent)

        let g2 = winGame(.opponent, &s)  // 总局数 2（偶）→ 不换边
        XCTAssertFalse(g2.contains(.changeEnds))
        XCTAssertEqual(s.server, .me)

        let g3 = winGame(.me, &s)        // 总局数 3（奇）→ 换边
        XCTAssertTrue(g3.contains(.changeEnds))
    }

    // MARK: - 播报（只报数字，发球方在前，专业读法）

    func testAnnouncementServerFirst_zh() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.pointsMe = 3; s.pointsOpp = 2

        s.server = .me
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .chinese),
                       "四十比三十")

        // 发球方在前：此时发球方是对方（只有 30 分）
        s.server = .opponent
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .chinese),
                       "三十比四十")
    }

    func testAnnouncementZeroReadsCorrectly() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.pointsMe = 0; s.pointsOpp = 2; s.server = .me

        // 中文：0 读「零」
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .chinese),
                       "零比三十")
        // 英文：0 读 love
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .english),
                       "love thirty")
    }

    func testAnnouncementAllWhenTied() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.pointsMe = 1; s.pointsOpp = 1; s.server = .me
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .chinese), "十五平")
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .english), "fifteen all")
    }

    func testAnnouncementDeuce_zh() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.pointsMe = 3; s.pointsOpp = 3
        XCTAssertEqual(builder.utterance(for: [.deuce], state: s, language: .chinese),
                       "平分，金球")
    }

    func testAnnouncementPoint_en() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.pointsMe = 3; s.pointsOpp = 2; s.server = .me
        XCTAssertEqual(builder.utterance(for: [.point], state: s, language: .english),
                       "forty thirty")
    }

    func testAnnouncementTiebreakNumbers() {
        let builder = AnnouncementBuilder()
        var s = stateInTiebreak(target: 4)
        s.tbMe = 0; s.tbOpp = 3; s.server = .me
        // 中文抢七：0 读「零」
        XCTAssertEqual(builder.utterance(for: [.tiebreakPoint], state: s, language: .chinese),
                       "零比3")
        // 英文抢七：0 读 zero（抢七惯例）
        XCTAssertEqual(builder.utterance(for: [.tiebreakPoint], state: s, language: .english),
                       "zero 3")
    }

    func testAnnouncementUsesTeamNames() {
        let builder = AnnouncementBuilder()
        var s = MatchState(config: MatchConfig(targetGames: 4, firstServer: .me,
                                               playersMe: ["暴龙队"], playersOpp: ["闪电队"]))
        s.gamesMe = 2; s.gamesOpp = 1
        // 拿下一局：带队名
        XCTAssertEqual(builder.utterance(for: [.gameWon(.me)], state: s, language: .chinese),
                       "暴龙队拿下这一局，局分2比1")
        // 换发球：带队名
        XCTAssertEqual(builder.utterance(for: [.serveChange(.opponent)], state: s, language: .chinese),
                       "该闪电队发球")
    }

    func testAnnouncementDoublesNames() {
        let builder = AnnouncementBuilder()
        var s = MatchState(config: MatchConfig(targetGames: 4, firstServer: .me,
                                               playersMe: ["张三", "李四"],
                                               playersOpp: ["Smith", "Jones"]))
        s.gamesMe = 1; s.gamesOpp = 0
        // 双打局末：两名队员用顿号连接（队赢了，报两人）
        XCTAssertEqual(builder.utterance(for: [.gameWon(.me)], state: s, language: .chinese),
                       "张三、李四拿下这一局，局分1比0")
        // 双打发球：报两名队员（具体谁发球双打可换，不单报一人）
        XCTAssertEqual(builder.utterance(for: [.serveChange(.opponent)], state: s, language: .english),
                       "Smith and Jones to serve")
    }

    func testAnnouncementTeamNameAndServer() {
        let builder = AnnouncementBuilder()
        var s = MatchState(config: MatchConfig(targetGames: 4, firstServer: .me,
                                               teamNameMe: "闪电队",
                                               playersMe: ["张三", "李四"],
                                               playersOpp: ["Smith", "Jones"]))
        s.gamesMe = 1
        // 局末只报队员名（队名只在发球时报，避免英文播报嵌中文队名卡顿）
        XCTAssertEqual(builder.utterance(for: [.gameWon(.me)], state: s, language: .chinese),
                       "张三、李四拿下这一局，局分1比0")
        // 发球：队名 + 两名队员都报（双打不单报一人）
        XCTAssertEqual(builder.utterance(for: [.serveChange(.me)], state: s, language: .chinese),
                       "该闪电队，张三、李四发球")
    }

    func testAnnouncementGameAndSet_zh() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.gamesMe = 4; s.gamesOpp = 2; s.winner = .me; s.phase = .finished
        XCTAssertEqual(builder.utterance(for: [.setWon(.me)], state: s, language: .chinese),
                       "我方以4比2拿下本盘，比赛结束")
    }

    func testAnnouncementTiebreakSetWon_zh() {
        let builder = AnnouncementBuilder()
        var s = makeState()
        s.gamesMe = 5; s.gamesOpp = 4; s.winner = .me; s.phase = .finished
        s.finishedByTiebreak = true
        XCTAssertEqual(builder.utterance(for: [.setWon(.me)], state: s, language: .chinese),
                       "我方以5比4抢七拿下本盘，比赛结束")
    }

    func testAnnouncementChangeEnds() {
        let builder = AnnouncementBuilder()
        let s = makeState()
        XCTAssertEqual(builder.utterance(for: [.changeEnds], state: s, language: .chinese), "换边")
        XCTAssertEqual(builder.utterance(for: [.changeEnds], state: s, language: .english), "Change ends")
    }
}

// MARK: - 内置人声清单

final class VoiceClipManifestTests: XCTestCase {

    /// 每个清单短句都有唯一 clipID；文本非空。
    func testClipIDsUniqueAndTextsNonEmpty() {
        let phrases = AnnouncementBuilder.allClipPhrases
        let ids = phrases.compactMap(\.clipID)
        XCTAssertEqual(ids.count, phrases.count, "清单里有短句缺 clipID")
        XCTAssertEqual(Set(ids).count, ids.count, "clipID 重复")
        for p in phrases {
            XCTAssertFalse(p.text(.chinese).isEmpty)
            XCTAssertFalse(p.text(.english).isEmpty)
        }
    }

    /// nameless 模式下，真实比赛流程里出现的每个短句都能在清单里找到片段。
    func testNamelessMatchPhrasesAreAllCovered() {
        let known = Set(AnnouncementBuilder.allClipPhrases.compactMap(\.clipID))
        let builder = AnnouncementBuilder()
        for target in [4, 6] {
            // 跑一场"每局都打到平分、抢七打到 7-5"的极限比赛，覆盖尽可能多的事件
            var s = MatchState(config: MatchConfig(targetGames: target, firstServer: .me))
            var turn = 0
            while s.phase != .finished && turn < 400 {
                let side: Side = (turn / 3) % 2 == 0 ? .me : .opponent
                let events = ScoreEngine.applyPoint(side, to: &s)
                for p in builder.phrases(for: events, state: s, language: .chinese, nameless: true) {
                    XCTAssertNotNil(p.clipID, "\(p) 没有 clipID")
                    if let id = p.clipID { XCTAssertTrue(known.contains(id), "清单缺 \(id)") }
                }
                turn += 1
            }
        }
    }

    /// 把清单导出为 JSON（供 tools/gen_voices.py 生成音频）。设置环境变量 REX_MANIFEST_OUT 时才写。
    func testDumpManifestIfRequested() throws {
        guard let out = ProcessInfo.processInfo.environment["REX_MANIFEST_OUT"], !out.isEmpty else { return }
        var rows: [[String: String]] = []
        for p in AnnouncementBuilder.allClipPhrases {
            rows.append(["id": p.clipID!, "zh": p.text(.chinese), "en": p.text(.english)])
        }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: out))
    }
}

// MARK: - 内置人声：真实读取随包片段并走 PA 烘焙（验证整条链路可用）

final class VoiceClipPipelineTests: XCTestCase {

    func testBundledClipsRenderAndBake() async throws {
        for lang in AnnounceLanguage.allCases {
            for umpire in UmpireVoice.allCases {
                guard VoiceClips.available(language: lang, umpire: umpire) else {
                    continue   // 未随包提供该组片段（如仅生成了部分声源）
                }
                let pcm = VoiceClips.render(clipIDs: ["score_1_2", "game_me_3_2", "serve_opponent"],
                                            language: lang, umpire: umpire)
                XCTAssertNotNil(pcm, "\(lang) \(umpire) 片段读取失败")
                guard let pcm else { continue }
                XCTAssertGreaterThan(pcm.frameLength, 44_100, "拼接后至少应有 1 秒音频")
                let data = await OfflineFX.bakeStadiumPAAsync(pcm, emphatic: false, seed: 7)
                XCTAssertNotNil(data, "\(lang) \(umpire) PA 烘焙失败")
                XCTAssertGreaterThan(data?.count ?? 0, 44, "WAV 应有内容")
            }
        }
    }

    func testMissingClipFallsBackToNil() {
        XCTAssertNil(VoiceClips.render(clipIDs: ["score_1_2", "no_such_clip"],
                                       language: .chinese, umpire: .female))
    }
}
