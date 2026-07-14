import Foundation

/// 纯逻辑计分引擎（无 UI / 无音频依赖，可完整单测）。
///
/// 规则要点：
/// - 每局无广告（金球）：先到 4 分胜局；40-40 为平分，下一分直接定局。
/// - 每盘目标 N 局（4 或 6）：局数 ≥N 且净胜 2 局胜盘；到 N-N 打抢七。
/// - 抢七：先到 7 分且净胜 2 分胜；发球 1-2-2-2 轮换；每 6 分换边。
/// - 单盘定胜负：胜盘即比赛结束。
enum ScoreEngine {

    /// 对 `state` 施加「`side` 得一分」，就地修改并返回按顺序发生的事件。
    @discardableResult
    static func applyPoint(_ side: Side, to state: inout MatchState) -> [MatchEvent] {
        guard state.phase != .finished else { return [] }
        var events: [MatchEvent] = []
        switch state.phase {
        case .tiebreak:
            applyTiebreakPoint(side, to: &state, events: &events)
        case .playing:
            applyGamePoint(side, to: &state, events: &events)
        case .finished:
            break
        }
        return events
    }

    /// 抢七发球方：已打 `played` 分时，即将发下一分的一方。
    /// 规则 1-2-2-2：starter 发第 1 分，其后每 2 分换发球。
    static func tiebreakServer(played: Int, starter: Side) -> Side {
        let group = (played + 1) / 2          // 0,1,1,2,2,3,3,...
        return group % 2 == 0 ? starter : starter.other
    }

    // MARK: - 常规局

    private static func applyGamePoint(_ side: Side, to s: inout MatchState, events: inout [MatchEvent]) {
        if side == .me { s.pointsMe += 1 } else { s.pointsOpp += 1 }

        // 无广告制：得分方先到 4 分即胜局（含平分后的金球分：4-3）。
        if s.pointsMe >= 4 || s.pointsOpp >= 4 {
            gameWon(by: side, to: &s, events: &events)
        } else if s.pointsMe == 3 && s.pointsOpp == 3 {
            events.append(.deuce)               // 40-40 平分（金球点）
        } else {
            events.append(.point)
        }
    }

    private static func gameWon(by side: Side, to s: inout MatchState, events: inout [MatchEvent]) {
        s.pointsMe = 0
        s.pointsOpp = 0
        if side == .me { s.gamesMe += 1 } else { s.gamesOpp += 1 }
        events.append(.gameWon(side))

        let winnerGames = s.games(for: side)
        let loserGames = s.games(for: side.other)
        let target = s.config.targetGames

        // 胜盘：达到目标局数且净胜 2 局。
        if winnerGames >= target && (winnerGames - loserGames) >= 2 {
            finishMatch(winner: side, to: &s, events: &events)
            return
        }

        // 到达 N-N：进入抢七。
        if s.gamesMe == target && s.gamesOpp == target {
            s.server = s.server.other            // 抢七由「下一个该发球方」开球
            s.tiebreakStarter = s.server
            s.tbMe = 0
            s.tbOpp = 0
            s.phase = .tiebreak
            events.append(.tiebreakStarted)
            events.append(.serveChange(s.server))
            return
        }

        // 常规换局：奇数总局数换边，随后交换发球方。
        let totalGames = s.gamesMe + s.gamesOpp
        if totalGames % 2 == 1 {
            events.append(.changeEnds)
        }
        s.advanceServerPlayer(for: s.server)   // 发完这局的队，下次发球换另一位队员（双打）
        s.server = s.server.other
        events.append(.serveChange(s.server))
    }

    // MARK: - 抢七

    private static func applyTiebreakPoint(_ side: Side, to s: inout MatchState, events: inout [MatchEvent]) {
        guard let starter = s.tiebreakStarter else { return }
        let playedBefore = s.tbMe + s.tbOpp
        if side == .me { s.tbMe += 1 } else { s.tbOpp += 1 }

        let winnerPts = s.tiebreakPoints(for: side)
        let loserPts = s.tiebreakPoints(for: side.other)

        // 抢七胜：先到 7 分且净胜 2 分。
        if winnerPts >= 7 && (winnerPts - loserPts) >= 2 {
            if side == .me { s.gamesMe += 1 } else { s.gamesOpp += 1 }   // 记为 N+1 : N
            finishMatch(winner: side, to: &s, events: &events)
            return
        }

        events.append(.tiebreakPoint)

        let playedAfter = s.tbMe + s.tbOpp
        // 每 6 分换边。
        if playedAfter % 6 == 0 {
            events.append(.changeEnds)
        }
        // 发球方轮换。
        let serverBefore = tiebreakServer(played: playedBefore, starter: starter)
        let serverAfter = tiebreakServer(played: playedAfter, starter: starter)
        s.server = serverAfter
        if serverBefore != serverAfter {
            events.append(.serveChange(serverAfter))
        }
    }

    private static func finishMatch(winner: Side, to s: inout MatchState, events: inout [MatchEvent]) {
        s.finishedByTiebreak = (s.phase == .tiebreak)   // 记录是否抢七决出
        s.phase = .finished
        s.winner = winner
        events.append(.setWon(winner))
    }
}
