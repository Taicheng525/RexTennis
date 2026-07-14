import SwiftUI

/// 赛前设置：顶部小胶囊切语言/声音；队伍卡（队名选填 + 1-2 名队员）；赛制卡。
/// 每队填第 2 个名字即为双打，自动判断。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me
    @State private var teamMe: String = SettingsStore.teamNameMe
    @State private var teamOpp: String = SettingsStore.teamNameOpp
    @State private var me1: String = SettingsStore.playersMe.first ?? ""
    @State private var me2: String = SettingsStore.playersMe.count > 1 ? SettingsStore.playersMe[1] : ""
    @State private var opp1: String = SettingsStore.playersOpp.first ?? ""
    @State private var opp2: String = SettingsStore.playersOpp.count > 1 ? SettingsStore.playersOpp[1] : ""

    private enum Field: Hashable { case teamMe, me1, me2, teamOpp, opp1, opp2 }
    @FocusState private var focused: Field?

    private var isChinese: Bool { appModel.language == .chinese }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }

    private var resolvedPlayersMe: [String] {
        let a = [trimmed(me1), trimmed(me2)].filter { !$0.isEmpty }
        return a.isEmpty ? [isChinese ? "我方" : "Team A"] : a
    }
    private var resolvedPlayersOpp: [String] {
        let a = [trimmed(opp1), trimmed(opp2)].filter { !$0.isEmpty }
        return a.isEmpty ? [isChinese ? "对方" : "Team B"] : a
    }
    /// 首发选择器上显示的名字：有队名用队名，否则队员名。
    private var displayMe: String {
        let t = trimmed(teamMe); return t.isEmpty ? resolvedPlayersMe.joined(separator: " / ") : t
    }
    private var displayOpp: String {
        let t = trimmed(teamOpp); return t.isEmpty ? resolvedPlayersOpp.joined(separator: " / ") : t
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    titleBlock
                        .padding(.top, 36)

                    // 播报语言 / 裁判声音（小胶囊，点击切换；比赛中也能随时切）
                    HStack(spacing: 10) {
                        settingPill(isChinese ? "中文" : "English") {
                            appModel.language = isChinese ? .english : .chinese
                        }
                        settingPill(isChinese ? (appModel.umpire == .female ? "♀ 女声" : "♂ 男声")
                                              : (appModel.umpire == .female ? "♀ Female" : "♂ Male")) {
                            appModel.umpire = appModel.umpire == .female ? .male : .female
                        }
                    }
                    .padding(.bottom, 2)

                    // ① 队伍（队名选填 + 1-2 名队员；填第 2 名即双打）
                    groupCard {
                        teamBlock(title: isChinese ? "我方" : "TEAM 1",
                                  team: $teamMe, p1: $me1, p2: $me2,
                                  tf: .teamMe, f1: .me1, f2: .me2)
                        Rectangle().fill(RexTheme.hairline).frame(height: 1)
                        teamBlock(title: isChinese ? "对方" : "TEAM 2",
                                  team: $teamOpp, p1: $opp1, p2: $opp2,
                                  tf: .teamOpp, f1: .opp1, f2: .opp2)
                        Text(isChinese ? "队名选填；每队填第 2 个名字即为双打"
                                       : "Team name optional; add a 2nd name for doubles")
                            .font(.caption2)
                            .foregroundStyle(RexTheme.textFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ② 赛制 + 首发
                    groupCard {
                        inlineRow(isChinese ? "赛制 · 一盘定胜负" : "FORMAT · SINGLE SET") {
                            Picker("", selection: $targetGames) {
                                Text(isChinese ? "4 局制" : "4 games").tag(4)
                                Text(isChinese ? "6 局制" : "6 games").tag(6)
                            }
                            .pickerStyle(.segmented)
                        }
                        inlineRow(isChinese ? "首个发球方" : "FIRST SERVER") {
                            Picker("", selection: $firstServer) {
                                Text(displayMe).tag(Side.me)
                                Text(displayOpp).tag(Side.opponent)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    startButton
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 22)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(RexTheme.accent)
    }

    // MARK: - 标题

    private var titleBlock: some View {
        VStack(spacing: 10) {
            TennisBall(size: 44)
            Text("RexTennis")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(RexTheme.text)
            Text(isChinese ? "蓝牙耳机 · 离线比分播报" : "OFFLINE SCORE ANNOUNCER")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(RexTheme.textDim)
        }
    }

    private func settingPill(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(RexTheme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RexTheme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(RexTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 队伍输入

    private func teamBlock(title: String, team: Binding<String>,
                           p1: Binding<String>, p2: Binding<String>,
                           tf: Field, f1: Field, f2: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(RexTheme.accent)
                    .frame(width: 3, height: 14)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(1.6)
                    .foregroundStyle(RexTheme.textDim)
            }
            nameField(isChinese ? "队名（选填）" : "Team name (optional)", text: team, field: tf)
            HStack(spacing: 8) {
                nameField(isChinese ? "队员 1" : "Player 1", text: p1, field: f1)
                nameField(isChinese ? "队员 2（选填）" : "Player 2 (optional)", text: p2, field: f2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nameField(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField("", text: text,
                  prompt: Text(placeholder).foregroundStyle(RexTheme.textFaint))
            .foregroundStyle(RexTheme.text)
            .font(.body.weight(.medium))
            .focused($focused, equals: field)
            .submitLabel(.done)
            .autocorrectionDisabled()
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focused == field ? RexTheme.accent.opacity(0.7) : RexTheme.hairline,
                                  lineWidth: 1)
            )
    }

    // MARK: - 分组卡 & 行

    private func groupCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 14) { content() }
            .padding(14)
            .frame(maxWidth: .infinity)
            .rexCard()
    }

    private func inlineRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .tracking(1.6)
                .foregroundStyle(RexTheme.textDim)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 开始按钮

    private var startButton: some View {
        Button {
            focused = nil
            SettingsStore.language = appModel.language
            SettingsStore.teamNameMe = trimmed(teamMe)
            SettingsStore.teamNameOpp = trimmed(teamOpp)
            SettingsStore.playersMe = resolvedPlayersMe
            SettingsStore.playersOpp = resolvedPlayersOpp
            appModel.startMatch(config: MatchConfig(targetGames: targetGames,
                                                    firstServer: firstServer,
                                                    teamNameMe: trimmed(teamMe),
                                                    teamNameOpp: trimmed(teamOpp),
                                                    playersMe: resolvedPlayersMe,
                                                    playersOpp: resolvedPlayersOpp))
        } label: {
            Text(isChinese ? "开始比赛" : "Start Match")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(RexTheme.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(colors: [RexTheme.green, RexTheme.green.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(RexTheme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetupView().environmentObject(AppModel())
}
