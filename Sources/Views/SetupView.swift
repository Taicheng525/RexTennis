import SwiftUI

/// 赛前设置：分三组——队伍、赛制、播报。全部有默认值，可直接开始。
/// 每队 1-2 名队员：填 1 个是单打，填 2 个是双打（自动判断）。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me
    @State private var me1: String = SettingsStore.playersMe.first ?? ""
    @State private var me2: String = SettingsStore.playersMe.count > 1 ? SettingsStore.playersMe[1] : ""
    @State private var opp1: String = SettingsStore.playersOpp.first ?? ""
    @State private var opp2: String = SettingsStore.playersOpp.count > 1 ? SettingsStore.playersOpp[1] : ""

    private enum Field: Hashable { case me1, me2, opp1, opp2 }
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
    private var displayMe: String { resolvedPlayersMe.joined(separator: " / ") }
    private var displayOpp: String { resolvedPlayersOpp.joined(separator: " / ") }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    titleBlock
                        .padding(.top, 40)
                        .padding(.bottom, 6)

                    // ① 队伍（每队 1-2 人：填第 2 个名字即为双打）
                    groupCard {
                        teamBlock(title: isChinese ? "我方" : "TEAM 1",
                                  p1: $me1, p2: $me2, f1: .me1, f2: .me2)
                        Rectangle().fill(RexTheme.hairline).frame(height: 1)
                        teamBlock(title: isChinese ? "对方" : "TEAM 2",
                                  p1: $opp1, p2: $opp2, f1: .opp1, f2: .opp2)
                        Text(isChinese ? "每队填第 2 个名字即为双打" : "Add a 2nd name for doubles")
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

                    // ③ 播报（语言 + 裁判声音）
                    groupCard {
                        inlineRow(isChinese ? "播报语言" : "LANGUAGE") {
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

    // MARK: - 队伍输入（一队一块：标题 + 1-2 个队员名）

    private func teamBlock(title: String,
                           p1: Binding<String>, p2: Binding<String>,
                           f1: Field, f2: Field) -> some View {
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
            nameField(isChinese ? "队员 1" : "Player 1", text: p1, field: f1)
            nameField(isChinese ? "队员 2（选填）" : "Player 2 (optional)", text: p2, field: f2)
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
            SettingsStore.playersMe = resolvedPlayersMe
            SettingsStore.playersOpp = resolvedPlayersOpp
            appModel.startMatch(config: MatchConfig(targetGames: targetGames,
                                                    firstServer: firstServer,
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
