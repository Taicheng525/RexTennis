import SwiftUI

/// 赛前设置。两张卡：
/// - 「对阵」：先选单打/双打；每队一个「队名（选填）」＋对应数量的队员名框。
/// - 「比赛设置」：赛制 / 首发（按队名或我方对方选）/ 播报语言 / 裁判声音，均带标签。
/// 队名与队员名相互独立、都可留空——只填队员名也能开赛。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me
    @State private var isDoubles: Bool = SettingsStore.isDoubles
    @State private var teamMe: String = SettingsStore.teamNameMe
    @State private var teamOpp: String = SettingsStore.teamNameOpp
    @State private var showTeamMe: Bool = !SettingsStore.teamNameMe.isEmpty
    @State private var showTeamOpp: Bool = !SettingsStore.teamNameOpp.isEmpty
    @State private var me1: String = SettingsStore.playersMe.first ?? ""
    @State private var me2: String = SettingsStore.playersMe.count > 1 ? SettingsStore.playersMe[1] : ""
    @State private var opp1: String = SettingsStore.playersOpp.first ?? ""
    @State private var opp2: String = SettingsStore.playersOpp.count > 1 ? SettingsStore.playersOpp[1] : ""

    private enum Field: Hashable { case teamMe, me1, me2, teamOpp, opp1, opp2 }
    @FocusState private var focused: Field?

    private var isChinese: Bool { appModel.language == .chinese }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }

    private var resolvedPlayersMe: [String] {
        var a = [trimmed(me1)]; if isDoubles { a.append(trimmed(me2)) }
        let f = a.filter { !$0.isEmpty }
        return f.isEmpty ? [isChinese ? "我方" : "You"] : f
    }
    private var resolvedPlayersOpp: [String] {
        var a = [trimmed(opp1)]; if isDoubles { a.append(trimmed(opp2)) }
        let f = a.filter { !$0.isEmpty }
        return f.isEmpty ? [isChinese ? "对方" : "Opponent"] : f
    }
    /// 首发选择器上的短标识：有队名用队名，否则「我方 / 对方」（不堆队员名）。
    private var labelMe: String { trimmed(teamMe).isEmpty ? (isChinese ? "我方" : "You") : trimmed(teamMe) }
    private var labelOpp: String { trimmed(teamOpp).isEmpty ? (isChinese ? "对方" : "Opponent") : trimmed(teamOpp) }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    titleBlock
                        .padding(.top, 40)
                        .padding(.bottom, 4)

                    // ① 对阵
                    groupCard(isChinese ? "对阵" : "MATCH-UP") {
                        Picker("", selection: $isDoubles.animation(.snappy(duration: 0.2))) {
                            Text(isChinese ? "单打" : "Singles").tag(false)
                            Text(isChinese ? "双打" : "Doubles").tag(true)
                        }
                        .pickerStyle(.segmented)

                        teamSection(isChinese ? "我方" : "YOUR SIDE",
                                    team: $teamMe, showTeam: $showTeamMe, p1: $me1, p2: $me2,
                                    tf: .teamMe, f1: .me1, f2: .me2)
                        Rectangle().fill(RexTheme.hairline).frame(height: 1)
                        teamSection(isChinese ? "对方" : "OPPONENT",
                                    team: $teamOpp, showTeam: $showTeamOpp, p1: $opp1, p2: $opp2,
                                    tf: .teamOpp, f1: .opp1, f2: .opp2)
                    }

                    // ② 比赛设置
                    groupCard(isChinese ? "比赛设置" : "MATCH SETTINGS") {
                        inlineRow(isChinese ? "赛制 · 一盘定胜负" : "FORMAT · SINGLE SET") {
                            Picker("", selection: $targetGames) {
                                Text(isChinese ? "4 局" : "4 games").tag(4)
                                Text(isChinese ? "6 局" : "6 games").tag(6)
                            }
                            .pickerStyle(.segmented)
                        }
                        inlineRow(isChinese ? "首个发球" : "FIRST SERVE") {
                            Picker("", selection: $firstServer) {
                                Text(labelMe).tag(Side.me)
                                Text(labelOpp).tag(Side.opponent)
                            }
                            .pickerStyle(.segmented)
                        }
                        inlineRow(isChinese ? "播报语言" : "ANNOUNCE IN") {
                            Picker("", selection: $appModel.language) {
                                Text("中文").tag(AnnounceLanguage.chinese)
                                Text("English").tag(AnnounceLanguage.english)
                            }
                            .pickerStyle(.segmented)
                        }
                        inlineRow(isChinese ? "裁判声音" : "UMPIRE VOICE") {
                            Picker("", selection: $appModel.umpire) {
                                Text(isChinese ? "女声" : "Female").tag(UmpireVoice.female)
                                Text(isChinese ? "男声" : "Male").tag(UmpireVoice.male)
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
            TennisBall(size: 46)
            Text("RexTennis")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(RexTheme.text)
            Text(isChinese ? "蓝牙耳机 · 离线比分播报" : "OFFLINE SCORE ANNOUNCER")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(RexTheme.textDim)
        }
    }

    // MARK: - 一队的输入：队名（选填）+ 队员名（单打 1 / 双打 2）

    private func teamSection(_ title: String, team: Binding<String>, showTeam: Binding<Bool>,
                             p1: Binding<String>, p2: Binding<String>,
                             tf: Field, f1: Field, f2: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(RexTheme.textDim)
                Spacer()
                if !showTeam.wrappedValue {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { showTeam.wrappedValue = true }
                    } label: {
                        Label(isChinese ? "队名" : "Team name", systemImage: "plus")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(RexTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            if showTeam.wrappedValue {
                HStack(spacing: 8) {
                    nameField(isChinese ? "队名" : "Team name", text: team, field: tf)
                    Button {
                        showTeam.wrappedValue = false
                        team.wrappedValue = ""
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(RexTheme.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            if isDoubles {
                nameField(isChinese ? "队员 1" : "Player 1", text: p1, field: f1)
                nameField(isChinese ? "队员 2" : "Player 2", text: p2, field: f2)
            } else {
                nameField(isChinese ? "队员姓名" : "Player name", text: p1, field: f1)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focused == field ? RexTheme.accent.opacity(0.7) : RexTheme.hairline,
                                  lineWidth: 1)
            )
    }

    // MARK: - 卡片 & 设置行（标签在上、控件在下，不换行）

    private func groupCard<Content: View>(_ title: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .tracking(1.8)
                .foregroundStyle(RexTheme.textDim)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rexCard()
    }

    private func inlineRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(RexTheme.textFaint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 开始按钮

    private var startButton: some View {
        Button {
            focused = nil
            SettingsStore.language = appModel.language
            SettingsStore.isDoubles = isDoubles
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
