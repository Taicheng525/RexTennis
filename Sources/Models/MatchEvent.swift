import Foundation

/// 计分引擎在一次得分后产生的事件（按发生顺序），供播报文案生成使用。
enum MatchEvent: Equatable {
    /// 常规局内的普通一分（读当前状态的局内比分播报）。
    case point
    /// 到达平分（40-40），即金球点。
    case deuce
    /// 某方拿下一局。
    case gameWon(Side)
    /// 进入抢七。
    case tiebreakStarted
    /// 抢七内的一分（读当前抢七比分播报）。
    case tiebreakPoint
    /// 需要换边。
    case changeEnds
    /// 发球方变更为指定一方。
    case serveChange(Side)
    /// 某方拿下本盘（单盘赛即比赛结束）。
    case setWon(Side)
}
