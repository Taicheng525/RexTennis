import SwiftUI

/// 比赛进行页：简约 dark 记分板 + 两个大得分按钮 + 撤销 / 再报一次。
struct MatchView: View {
    @ObservedObject var viewModel: MatchViewModel
    @EnvironmentObject private var appModel: AppModel

    private var state: MatchState { viewModel.state }
    private var isChinese: Bool { viewModel.language == .chinese }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                header
                Spacer(minLength: 0)
                scoreboard
                statusHint
                soundBoard
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
                    .foregroundStyle(RexTheme.text.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RexTheme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(RexTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(phaseTitle)
                .font(.system(size: 13, weight: .bold, design: .serif))
                .tracking(2)
                .foregroundStyle(RexTheme.textDim)

            Spacer()

            HStack(spacing: 8) {
                // 裁判声音切换：女(♀) / 男(♂)
                pillButton(viewModel.umpire == .female ? "♀" : "♂") {
                    viewModel.umpire = viewModel.umpire == .female ? .male : .female
                }
                // 语言切换：中 / EN
                pillButton(isChinese ? "中" : "EN") {
                    viewModel.language = isChinese ? .english : .chinese
                }
            }
        }
    }

    private func pillButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RexTheme.text)
                .frame(width: 40, height: 30)
                .background(RexTheme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(RexTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                .fill(RexTheme.hairline)
                .frame(height: 1)
                .padding(.horizontal, 14)
            playerRow(.opponent)
        }
        .rexCard(cornerRadius: 22)
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
        .foregroundStyle(RexTheme.textFaint)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func playerRow(_ side: Side) -> some View {
        let isServer = !viewModel.isFinished && state.server == side
        return HStack(spacing: 12) {
            // 发球指示
            ZStack {
                if isServer { TennisBall(size: 14) }
            }
            .frame(width: 18)

            // 小标题：队名（若有）；大标题：队员姓名
            VStack(alignment: .leading, spacing: 1) {
                if !state.config.teamName(for: side).isEmpty {
                    Text(state.config.teamName(for: side))
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .tracking(0.5)
                        .foregroundStyle(RexTheme.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(state.config.players(for: side).joined(separator: " / "))
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(RexTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 4)

            // 本盘局数
            Text("\(state.games(for: side))")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(RexTheme.text.opacity(0.9))
                .frame(width: 52)

            // 当前局 / 抢七 得分
            Text(state.gameScoreLabel(for: side))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(RexTheme.accent)
                .frame(width: 86)
                .padding(.vertical, 8)
                .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 状态提示

    @ViewBuilder
    private var statusHint: some View {
        if viewModel.isFinished, let winner = state.winner {
            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(RexTheme.accent)
                Text(isChinese
                     ? "\(state.config.name(for: winner)) 胜 · \(state.games(for: winner)) : \(state.games(for: winner.other))"
                     : "\(state.config.name(for: winner)) wins · \(state.games(for: winner)) : \(state.games(for: winner.other))")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(RexTheme.text)
            }
            .multilineTextAlignment(.center)
        } else if viewModel.showChangeEnds {
            // 纯文字提醒（非按钮）
            HStack(spacing: 7) {
                Image(systemName: "arrow.left.arrow.right")
                Text(isChinese ? "换边" : "CHANGE ENDS")
                    .tracking(1.5)
            }
            .font(.system(size: 14, weight: .heavy, design: .serif))
            .foregroundStyle(RexTheme.accent)
            .padding(.vertical, 8)
        } else if state.isDeuce {
            Text(isChinese ? "平分 · 金球" : "DEUCE · DECIDING POINT")
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .tracking(1.5)
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(RexTheme.accent, in: Capsule())
        } else {
            Text(" ").font(.system(size: 13)).padding(.vertical, 7)
        }
    }

    // MARK: - 欢呼音效

    private var soundBoard: some View {
        VStack(spacing: 7) {
            categoryHeader(isChinese ? "观众" : "CROWD")
            HStack(spacing: 6) {
                cheerButton("hands.clap.fill", .applause)
                cheerButton("music.mic", .cheer)
                cheerButton("party.popper.fill", .bigcheer)
                cheerButton("person.3.fill", .cheers)
                cheerButton("hand.thumbsdown.fill", .groan)
            }
            categoryHeader(isChinese ? "裁判" : "UMPIRE")
            HStack(spacing: 6) {
                callButton("hand.raised.fill", .quiet)
                callButton("xmark.circle.fill", .out)
                callButton("1.circle.fill", .letFirst)
                callButton("2.circle.fill", .letSecond)
                silenceButton
            }
        }
        .padding(.top, 4)
    }

    /// 分类小标题
    private func categoryHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .serif))
            .tracking(1.5)
            .foregroundStyle(RexTheme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 一键静音：立即停掉语音 + 所有音效
    private var silenceButton: some View {
        Button {
            viewModel.silenceAll()
        } label: {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.red.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RexTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.red.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// 裁判喊话按钮（TTS 生成，与报分同一裁判声线）
    private func callButton(_ icon: String, _ call: AnnouncementBuilder.UmpireCall) -> some View {
        Button {
            viewModel.umpireCall(call)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RexTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RexTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(RexTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func cheerButton(_ icon: String, _ kind: SoundEffects.Kind) -> some View {
        Button {
            viewModel.cheer(kind)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RexTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RexTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(RexTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }


    // MARK: - 得分控制

    private var scoringControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                scoreButton(.me,
                            fill: LinearGradient(colors: [RexTheme.green, RexTheme.green.opacity(0.72)],
                                                 startPoint: .top, endPoint: .bottom),
                            textColor: RexTheme.cream)
                scoreButton(.opponent,
                            fill: LinearGradient(colors: [RexTheme.cream, RexTheme.cream.opacity(0.85)],
                                                 startPoint: .top, endPoint: .bottom),
                            textColor: RexTheme.onCream)
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

    private func scoreButton(_ side: Side, fill: LinearGradient, textColor: Color) -> some View {
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
                    .strokeBorder(RexTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func utilityButton(_ title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(RexTheme.text.opacity(disabled ? 0.30 : 0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RexTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(RexTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
    }

    // MARK: - 结束控制

    private var finishedControls: some View {
        Button {
            appModel.endMatch()
        } label: {
            Text(isChinese ? "再来一场" : "Play Again")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(RexTheme.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(colors: [RexTheme.green, RexTheme.green.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    MatchView(viewModel: MatchViewModel(config: .default, language: .chinese))
        .environmentObject(AppModel())
}
