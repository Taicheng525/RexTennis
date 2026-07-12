import SwiftUI

/// 比赛进行页：记分板 + 两个大得分按钮 + 撤销 / 再报一次。
struct MatchView: View {
    @ObservedObject var viewModel: MatchViewModel
    @EnvironmentObject private var appModel: AppModel

    private var state: MatchState { viewModel.state }
    private var isChinese: Bool { viewModel.language == .chinese }

    var body: some View {
        VStack(spacing: 16) {
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
        .padding(.vertical, 12)
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
            }

            Spacer()

            Text(phaseTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.language = isChinese ? .english : .chinese
            } label: {
                Text(isChinese ? "中" : "EN")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 28)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var phaseTitle: String {
        switch state.phase {
        case .tiebreak: return isChinese ? "抢七" : "TIE-BREAK"
        case .finished: return isChinese ? "比赛结束" : "MATCH OVER"
        case .playing:
            return isChinese
                ? "\(state.config.targetGames) 局制"
                : "\(state.config.targetGames)-game set"
        }
    }

    // MARK: - 记分板

    private var scoreboard: some View {
        VStack(spacing: 12) {
            playerRow(.me)
            Divider()
            playerRow(.opponent)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func playerRow(_ side: Side) -> some View {
        let isServer = !viewModel.isFinished && state.server == side
        return HStack(spacing: 12) {
            Text(isServer ? "🎾" : " ")
                .font(.title3)
                .frame(width: 24)

            Text(name(side))
                .font(.title2.weight(.semibold))
                .foregroundStyle(side == .me ? Color.green : Color.cyan)

            Spacer()

            // 本盘局数
            VStack(spacing: 2) {
                Text(isChinese ? "局" : "GAMES").font(.caption2).foregroundStyle(.secondary)
                Text("\(state.games(for: side))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 56)

            // 当前局 / 抢七 得分
            VStack(spacing: 2) {
                Text(state.phase == .tiebreak ? (isChinese ? "抢七" : "TB") : (isChinese ? "分" : "PTS"))
                    .font(.caption2).foregroundStyle(.secondary)
                Text(state.gameScoreLabel(for: side))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(width: 78)
        }
    }

    // MARK: - 状态提示

    @ViewBuilder
    private var statusHint: some View {
        if viewModel.isFinished, let winner = state.winner {
            Text(isChinese
                 ? "🏆 \(name(winner)) 拿下本盘 \(state.games(for: winner)) : \(state.games(for: winner.other))"
                 : "🏆 \(name(winner)) wins \(state.games(for: winner)) : \(state.games(for: winner.other))")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        } else if state.isDeuce {
            Text(isChinese ? "平分 · 金球点" : "Deuce · sudden death")
                .font(.headline)
                .foregroundStyle(.orange)
        } else {
            Text(" ").font(.headline)
        }
    }

    // MARK: - 得分控制

    private var scoringControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                scoreButton(.me, color: .green)
                scoreButton(.opponent, color: .cyan)
            }
            HStack(spacing: 14) {
                Button {
                    viewModel.undo()
                } label: {
                    Label(isChinese ? "撤销" : "Undo", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canUndo)

                Button {
                    viewModel.repeatCurrentScore()
                } label: {
                    Label(isChinese ? "再报一次" : "Repeat", systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func scoreButton(_ side: Side, color: Color) -> some View {
        Button {
            viewModel.score(side)
        } label: {
            VStack(spacing: 6) {
                Text(name(side)).font(.title3.weight(.bold))
                Text("+1").font(.system(size: 34, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    // MARK: - 结束控制

    private var finishedControls: some View {
        Button {
            appModel.endMatch()
        } label: {
            Text(isChinese ? "再来一场" : "Play again")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    // MARK: - 工具

    private func name(_ side: Side) -> String {
        switch (side, isChinese) {
        case (.me, true): return "我方"
        case (.opponent, true): return "对方"
        case (.me, false): return "You"
        case (.opponent, false): return "Opponent"
        }
    }
}

#Preview {
    MatchView(viewModel: MatchViewModel(config: .default, language: .chinese))
        .environmentObject(AppModel())
}
