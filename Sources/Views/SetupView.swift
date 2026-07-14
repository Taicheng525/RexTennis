import SwiftUI

/// 赛前设置：两张卡——「对阵」（每队默认 1 个名字，点开可加双打队友）＋「比赛设置」
/// （赛制/首发/播报语言/裁判声音，均带清楚标签）。名字都可留空，用默认名直接开赛。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me
    @State private var me1: String = SettingsStore.playersMe.first ?? ""
    @State private var me2: String = SettingsStore.playersMe.count > 1 ? SettingsStore.playersMe[1] : ""
    @State private var opp1: String = SettingsStore.playersOpp.first ?? ""
    @State private var opp2: String = SettingsStore.playersOpp.count > 1 ? SettingsStore.playersOpp[1] : ""
    @State private var meDoubles: Bool = SettingsStore.playersMe.count > 1
    @State private var oppDoubles: Bool = SettingsStore.playersOpp.count > 1

    private enum Field: Hashable { case me1, me2, opp1, opp2 }
    @FocusState private var focused: Field?

    private var isChinese: Bool { appModel.language == .chinese }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }

    private var resolvedPlayersMe: [String] {
        var a = [trimmed(me1)]
        if meDoubles { a.append(trimmed(me2)) }
        let f = a.filter { !$0.isEmpty }
        return f.isEmpty ? [isChinese ? "我方" : "You"] : f
    }
    private var resolvedPlayersOpp: [String] {
        var a = [trimmed(opp1)]
        if oppDoubles { a.append(trimmed(opp2)) }
        let f = a.filter { !$0.isEmpty }
        return f.isEmpty ? [isChinese ? "对方" : "Opponent"] : f
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
                        .padding(.bottom, 4)

                    // ① 对阵（每队默认 1 个名字；点「双打」加队友）
                    groupCard(isChinese ? "对阵" : "MATCH-UP") {
                        teamRow(isChinese ? "我方" : "You",
                                p1: $me1, p2: $me2, doubles: $meDoubles, f1: .me1, f2: .me2)
                        Rectangle().fill(RexTheme.hairline).frame(height: 1)
                        teamRow(isChinese ? "对方" : "Opponent",
                                p1: $opp1, p2: $opp2, doubles: $oppDoubles, f1: .opp1, f2: .opp2)
                    }

                    // ② 比赛设置
                    groupCard(isChinese ? "比赛设置" : "MATCH SETTINGS") {
                        settingRow(isChinese ? "赛制" : "Format") {
                            Picker("", selection: $targetGames) {
                                Text(isChinese ? "4 局" : "4 games").tag(4)
                                Text(isChinese ? "6 局" : "6 games").tag(6)
                            }
                            .pickerStyle(.segmented)
                        }
                        settingRow(isChinese ? "首个发球" : "First serve") {
                            Picker("", selection: $firstServer) {
                                Text(displayMe).tag(Side.me)
                                Text(displayOpp).tag(Side.opponent)
                            }
                            .pickerStyle(.segmented)
                        }
                        settingRow(isChinese ? "播报语言" : "Announce in") {
                            Picker("", selection: $appModel.language) {
                                Text("中文").tag(AnnounceLanguage.chinese)
                                Text("English").tag(AnnounceLanguage.english)
                            }
                            .pickerStyle(.segmented)
                        }
                        settingRow(isChinese ? "裁判声音" : "Umpire voice") {
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

    // MARK: - 对阵：一队一行，默认单个名字，可展开双打

    private func teamRow(_ placeholder: String,
                         p1: Binding<String>, p2: Binding<String>,
                         doubles: Binding<Bool>, f1: Field, f2: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            nameField(placeholder, text: p1, field: f1)
            if doubles.wrappedValue {
                HStack(spacing: 8) {
                    nameField(isChinese ? "队友" : "Partner", text: p2, field: f2)
                    Button {
                        doubles.wrappedValue = false
                        p2.wrappedValue = ""
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(RexTheme.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { doubles.wrappedValue = true }
                } label: {
                    Label(isChinese ? "双打 · 加队友" : "Doubles · add partner",
                          systemImage: "plus.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RexTheme.accent)
                }
                .buttonStyle(.plain)
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
            .padding(.vertical, 12)
            .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focused == field ? RexTheme.accent.opacity(0.7) : RexTheme.hairline,
                                  lineWidth: 1)
            )
    }

    // MARK: - 卡片 & 设置行

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

    /// 一行设置：左侧标签 + 右侧控件（标签让「中文 / 女声」等选项一眼看懂含义）。
    private func settingRow<Content: View>(_ label: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(RexTheme.text)
                .frame(width: 76, alignment: .leading)
            content()
        }
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
