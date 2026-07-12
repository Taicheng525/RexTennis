import SwiftUI

/// 赛前设置：主题、队名、局数制、首发方、播报语言。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me
    @State private var nameMe: String = SettingsStore.nameMe
    @State private var nameOpp: String = SettingsStore.nameOpp
    @FocusState private var focusedField: Side?

    private var theme: CourtTheme { appModel.theme }
    private var isChinese: Bool { appModel.language == .chinese }

    /// 队名留空时的默认值。
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
            CourtBackground(theme: theme)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    titleBlock
                        .padding(.top, 24)

                    themePicker

                    sectionCard(isChinese ? "队伍名称" : "Teams") {
                        VStack(spacing: 10) {
                            teamField(isChinese ? "我方名称" : "Your team", text: $nameMe, side: .me)
                            teamField(isChinese ? "对方名称" : "Opponent team", text: $nameOpp, side: .opponent)
                        }
                    }

                    sectionCard(isChinese ? "赛制 · 一盘定胜负" : "Format · single set") {
                        Picker("", selection: $targetGames) {
                            Text(isChinese ? "4 局制" : "4 games").tag(4)
                            Text(isChinese ? "6 局制" : "6 games").tag(6)
                        }
                        .pickerStyle(.segmented)
                    }

                    sectionCard(isChinese ? "首个发球方" : "First server") {
                        Picker("", selection: $firstServer) {
                            Text(resolvedNameMe).tag(Side.me)
                            Text(resolvedNameOpp).tag(Side.opponent)
                        }
                        .pickerStyle(.segmented)
                    }

                    sectionCard(isChinese ? "播报语言" : "Announcement") {
                        Picker("", selection: $appModel.language) {
                            Text("中文").tag(AnnounceLanguage.chinese)
                            Text("English").tag(AnnounceLanguage.english)
                        }
                        .pickerStyle(.segmented)
                    }

                    startButton
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(theme.badge)
    }

    // MARK: - 标题

    private var titleBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TennisBall(size: 18)
                Text("RexTennis")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(theme.line)
                TennisBall(size: 18)
            }
            Text(theme.subtitle)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .tracking(3)
                .foregroundStyle(theme.line.opacity(0.7))
            Text(isChinese ? "蓝牙耳机 · 离线比分播报" : "Offline score announcer")
                .font(.footnote)
                .foregroundStyle(theme.line.opacity(0.55))
        }
    }

    // MARK: - 主题选择

    private var themePicker: some View {
        HStack(spacing: 10) {
            ForEach(CourtTheme.allCases) { t in
                Button {
                    withAnimation(.snappy) { appModel.theme = t }
                } label: {
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [t.court, t.courtDeep],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: 46)
                            .overlay(
                                CourtLines()
                                    .stroke(t.line.opacity(0.5), lineWidth: 0.8)
                                    .padding(3)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text(t.title(zh: isChinese))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.line.opacity(t == theme ? 1 : 0.65))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(t == theme ? 0.38 : 0.16),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(t == theme ? theme.badge : theme.line.opacity(0.12),
                                          lineWidth: t == theme ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 队名输入

    private func teamField(_ placeholder: String, text: Binding<String>, side: Side) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(side == .me ? theme.homeAccent : theme.awayAccent)
                .frame(width: 10, height: 10)
            TextField("", text: text,
                      prompt: Text(placeholder).foregroundStyle(theme.line.opacity(0.35)))
                .foregroundStyle(theme.line)
                .font(.body.weight(.medium))
                .focused($focusedField, equals: side)
                .submitLabel(.done)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focusedField == side ? theme.badge.opacity(0.8) : theme.line.opacity(0.12),
                              lineWidth: 1)
        )
    }

    // MARK: - 卡片与开始按钮

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .serif))
                .tracking(1.5)
                .foregroundStyle(theme.line.opacity(0.75))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme)
    }

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
                .foregroundStyle(theme.onHome)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(theme.homeAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(theme.line.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetupView().environmentObject(AppModel())
}
