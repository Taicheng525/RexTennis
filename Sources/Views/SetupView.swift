import SwiftUI

/// 赛前设置。两张卡：
/// - 「对阵」：单打/双打；每队可选加「队名」＋队员名。名字框右侧下拉可从名单快速选；
///   顶部「管理名单」可批量录入队员名/队名。
/// - 「比赛设置」：赛制 / 首发 / 播报语言 / 裁判声音，均带标签。
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
    @State private var playerRoster: [String] = SettingsStore.playerRoster
    @State private var teamRoster: [String] = SettingsStore.teamRoster
    @State private var showRoster = false

    private enum Field: Hashable { case teamMe, me1, me2, teamOpp, opp1, opp2 }
    @FocusState private var focused: Field?

    private var isChinese: Bool { appModel.language == .chinese }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
    /// 某个位置：填了就用填的，空着给中性默认名。
    private func slot(_ raw: String, zh: String, en: String) -> String {
        let t = trimmed(raw)
        return t.isEmpty ? (isChinese ? zh : en) : t
    }

    /// 我方队员：单打 1 人（默认「选手 1」），双打 2 人（默认「选手 1 / 选手 2」）。
    private var resolvedPlayersMe: [String] {
        isDoubles ? [slot(me1, zh: "选手 1", en: "Player 1"), slot(me2, zh: "选手 2", en: "Player 2")]
                  : [slot(me1, zh: "选手 1", en: "Player 1")]
    }
    /// 对方队员：单打默认「选手 2」，双打默认「选手 3 / 选手 4」（不与我方重名）。
    private var resolvedPlayersOpp: [String] {
        isDoubles ? [slot(opp1, zh: "选手 3", en: "Player 3"), slot(opp2, zh: "选手 4", en: "Player 4")]
                  : [slot(opp1, zh: "选手 2", en: "Player 2")]
    }
    /// 首发选择器上的短标识：有队名用队名，否则用队员名（没填则中性「选手 1/2」）。
    private var labelMe: String { trimmed(teamMe).isEmpty ? resolvedPlayersMe.joined(separator: " / ") : trimmed(teamMe) }
    private var labelOpp: String { trimmed(teamOpp).isEmpty ? resolvedPlayersOpp.joined(separator: " / ") : trimmed(teamOpp) }

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
                        HStack {
                            Spacer()
                            Button { showRoster = true } label: {
                                Label(isChinese ? "管理名单" : "Roster",
                                      systemImage: "person.2.crop.square.stack.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(RexTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        Picker("", selection: $isDoubles.animation(.snappy(duration: 0.2))) {
                            Text(isChinese ? "单打" : "Singles").tag(false)
                            Text(isChinese ? "双打" : "Doubles").tag(true)
                        }
                        .pickerStyle(.segmented)

                        teamSection(isChinese ? "队伍 1" : "TEAM 1",
                                    team: $teamMe, showTeam: $showTeamMe, p1: $me1, p2: $me2,
                                    tf: .teamMe, f1: .me1, f2: .me2)
                        Rectangle().fill(RexTheme.hairline).frame(height: 1)
                        teamSection(isChinese ? "队伍 2" : "TEAM 2",
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
        .sheet(isPresented: $showRoster, onDismiss: {
            playerRoster = SettingsStore.playerRoster
            teamRoster = SettingsStore.teamRoster
        }) {
            RosterEditorView(isChinese: isChinese)
        }
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

    // MARK: - 一队的输入：队名（可选）+ 队员名（单打 1 / 双打 2）

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
                    nameField(isChinese ? "队名" : "Team name", text: team, field: tf, roster: teamRoster)
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
                nameField(isChinese ? "队员 1" : "Player 1", text: p1, field: f1, roster: playerRoster)
                nameField(isChinese ? "队员 2" : "Player 2", text: p2, field: f2, roster: playerRoster)
            } else {
                nameField(isChinese ? "队员姓名" : "Player name", text: p1, field: f1, roster: playerRoster)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 输入框 + 右侧「从名单选」下拉（名单为空时不显示下拉）。
    private func nameField(_ placeholder: String, text: Binding<String>,
                           field: Field, roster: [String]) -> some View {
        HStack(spacing: 6) {
            TextField("", text: text,
                      prompt: Text(placeholder).foregroundStyle(RexTheme.textFaint))
                .foregroundStyle(RexTheme.text)
                .font(.body.weight(.medium))
                .focused($focused, equals: field)
                .submitLabel(.done)
                .autocorrectionDisabled()
            if !roster.isEmpty {
                Menu {
                    ForEach(roster, id: \.self) { name in
                        Button(name) { text.wrappedValue = name; focused = nil }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(RexTheme.accent.opacity(0.8))
                }
            }
        }
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
            // 记住实际填写过的名字（不含默认占位），供下次直接选择
            SettingsStore.remember(players: [me1, me2, opp1, opp2].map(trimmed).filter { !$0.isEmpty })
            SettingsStore.remember(teams: [teamMe, teamOpp].map(trimmed).filter { !$0.isEmpty })
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
