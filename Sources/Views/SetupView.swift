import SwiftUI

/// 赛前设置：分三组——队伍、赛制、播报。全部有默认值，可直接开始。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me
    @State private var nameMe: String = SettingsStore.nameMe
    @State private var nameOpp: String = SettingsStore.nameOpp
    @FocusState private var focusedField: Side?

    private var isChinese: Bool { appModel.language == .chinese }

    private var resolvedNameMe: String {
        let t = nameMe.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? (isChinese ? "我方" : "Team A") : t
    }
    private var resolvedNameOpp: String {
        let t = nameOpp.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? (isChinese ? "对方" : "Team B") : t
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    titleBlock
                        .padding(.top, 40)
                        .padding(.bottom, 6)

                    // ① 队伍
                    groupCard {
                        teamField(isChinese ? "我方名称" : "Your team", text: $nameMe, side: .me)
                        teamField(isChinese ? "对方名称" : "Opponent team", text: $nameOpp, side: .opponent)
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
                                Text(resolvedNameMe).tag(Side.me)
                                Text(resolvedNameOpp).tag(Side.opponent)
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

    // MARK: - 队名输入

    private func teamField(_ placeholder: String, text: Binding<String>, side: Side) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(side == .me ? RexTheme.green : RexTheme.cream)
                .frame(width: 9, height: 9)
            TextField("", text: text,
                      prompt: Text(placeholder).foregroundStyle(RexTheme.textFaint))
                .foregroundStyle(RexTheme.text)
                .font(.body.weight(.medium))
                .focused($focusedField, equals: side)
                .submitLabel(.done)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focusedField == side ? RexTheme.accent.opacity(0.7) : RexTheme.hairline,
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
            focusedField = nil
            SettingsStore.language = appModel.language
            SettingsStore.nameMe = nameMe
            SettingsStore.nameOpp = nameOpp
            appModel.startMatch(config: MatchConfig(targetGames: targetGames,
                                                    firstServer: firstServer,
                                                    nameMe: resolvedNameMe,
                                                    nameOpp: resolvedNameOpp))
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
