import SwiftUI

/// 比赛进行页：主题化记分板 + 两个大得分按钮 + 撤销 / 再报一次。
struct MatchView: View {
    @ObservedObject var viewModel: MatchViewModel
    @EnvironmentObject private var appModel: AppModel

    private var state: MatchState { viewModel.state }
    private var theme: CourtTheme { appModel.theme }
    private var isChinese: Bool { viewModel.language == .chinese }

    var body: some View {
        ZStack {
            CourtBackground(theme: theme)

            VStack(spacing: 14) {
                header
                Spacer(minLength: 0)
                scoreboard
                statusHint
                Spacer(minLength: 0)
                if viewModel.isFinished {
                    finishedControls
                } else {
                    scoringControls
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }   // 比赛中保持亮屏
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack {
            Button {
                appModel.endMatch()
            } label: {
                Label(isChinese ? "新比赛" : "New", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.line.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.25), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(phaseTitle)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .tracking(1.5)
                    .foregroundStyle(theme.line)
                Text(theme.subtitle)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(theme.line.opacity(0.5))
            }

            Spacer()

            Button {
                viewModel.language = isChinese ? .english : .chinese
            } label: {
                Text(isChinese ? "中" : "EN")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.line)
                    .frame(width: 40, height: 30)
                    .background(.black.opacity(0.25), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var phaseTitle: String {
        switch state.phase {
        case .tiebreak: return isChinese ? "抢 七" : "TIE-BREAK"
        case .finished: return isChinese ? "比赛结束" : "MATCH OVER"
        case .playing:
            return isChinese
                ? "\(state.config.targetGames) 局制"
                : "\(state.config.targetGames)-GAME SET"
        }
    }

    // MARK: - 记分板

    private var scoreboard: some View {
        VStack(spacing: 0) {
            columnLabels
            playerRow(.me)
            Rectangle()
                .fill(theme.line.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 14)
            playerRow(.opponent)
        }
        .themedCard(theme, cornerRadius: 22)
    }

    /// 列标题（局 / 分）。
    private var columnLabels: some View {
        HStack(spacing: 12) {
            Spacer()
            Text(isChinese ? "局" : "GAMES")
                .frame(width: 52)
            Text(state.phase == .tiebreak ? (isChinese ? "抢七" : "TB") : (isChinese ? "分" : "POINTS"))
                .frame(width: 86)
        }
        .font(.system(size: 10, weight: .bold, design: .serif))
        .tracking(1)
        .foregroundStyle(theme.line.opacity(0.55))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func playerRow(_ side: Side) -> some View {
        let isServer = !viewModel.isFinished && state.server == side
        return HStack(spacing: 12) {
            // 发球指示
            ZStack {
                if isServer { TennisBall(size: 13) }
            }
            .frame(width: 16)

            Text(state.config.name(for: side))
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(theme.line)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 4)

            // 本盘局数
            Text("\(state.games(for: side))")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.line.opacity(0.9))
                .frame(width: 52)

            // 当前局 / 抢七 得分
            Text(state.gameScoreLabel(for: side))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.badge)
                .frame(width: 86)
                .padding(.vertical, 8)
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 状态提示

    @ViewBuilder
    private var statusHint: some View {
        if viewModel.isFinished, let winner = state.winner {
            VStack(spacing: 4) {
                Text("🏆")
                    .font(.system(size: 34))
                Text(isChinese
                     ? "\(state.config.name(for: winner)) 胜 · \(state.games(for: winner)) : \(state.games(for: winner.other))"
                     : "\(state.config.name(for: winner)) wins · \(state.games(for: winner)) : \(state.games(for: winner.other))")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(theme.line)
            }
            .multilineTextAlignment(.center)
        } else if state.isDeuce {
            Text(isChinese ? "平分 · 金球" : "DEUCE · DECIDING POINT")
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .tracking(1.5)
                .foregroundStyle(theme.courtDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(theme.badge, in: Capsule())
        } else {
            Text(" ").font(.system(size: 13)).padding(.vertical, 7)
        }
    }

    // MARK: - 得分控制

    private var scoringControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                scoreButton(.me, fill: theme.homeAccent, textColor: theme.onHome)
                scoreButton(.opponent, fill: theme.awayAccent, textColor: theme.onAway)
            }
            HStack(spacing: 12) {
                utilityButton(isChinese ? "撤销" : "Undo",
                              icon: "arrow.uturn.backward",
                              disabled: !viewModel.canUndo) {
                    viewModel.undo()
                }
                utilityButton(isChinese ? "再报一次" : "Repeat",
                              icon: "speaker.wave.2.fill",
                              disabled: false) {
                    viewModel.repeatCurrentScore()
                }
            }
        }
    }

    private func scoreButton(_ side: Side, fill: Color, textColor: Color) -> some View {
        Button {
            viewModel.score(side)
        } label: {
            VStack(spacing: 5) {
                Text(state.config.name(for: side))
                    .font(.system(.headline, design: .serif).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("+1")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.line.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func utilityButton(_ title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(theme.line.opacity(disabled ? 0.35 : 0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(theme.line.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - 结束控制

    private var finishedControls: some View {
        Button {
            appModel.endMatch()
        } label: {
            Text(isChinese ? "再来一场" : "Play Again")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(theme.onHome)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(theme.homeAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MatchView(viewModel: MatchViewModel(config: .default, language: .chinese))
        .environmentObject(AppModel())
}
