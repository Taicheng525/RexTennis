import SwiftUI
import AVFoundation

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

    /// 整场人声语言：完全跟随所选播报语言（与 Announcer 一致）。
    private var effectiveVoiceCode: String { appModel.language.voiceCode }

    /// 英文播报但队名是中文——英文人声读不出中文字，提示用户改用英文队名。
    private var nameLanguageMismatch: Bool {
        appModel.language == .english
            && (resolvedNameMe.containsCJKText || resolvedNameOpp.containsCJKText)
    }

    /// 当前实际会用到的裁判人声——让用户确认下载的增强/高级人声是否被选中。
    private var currentVoice: AVSpeechSynthesisVoice? {
        Announcer.pickVoice(languageCode: effectiveVoiceCode, umpire: appModel.umpire)
    }
    /// 当前人声是否为「标准」档（偏机械，需引导用户下载增强/高级）。
    private var currentVoiceIsDefault: Bool {
        guard let v = currentVoice else { return true }
        return v.quality != .premium && v.quality != .enhanced
    }
    private func qualityLabel(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium:  return isChinese ? "高级" : "Premium"
        case .enhanced: return isChinese ? "增强" : "Enhanced"
        default:        return isChinese ? "标准" : "Default"
        }
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
                        if nameLanguageMismatch {
                            Label(isChinese
                                  ? "英文播报读不出中文队名，建议把队名也改成英文"
                                  : "English voice can't read Chinese team names — use English names",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.85))
                        }
                        if let v = currentVoice {
                            Label {
                                Text((isChinese ? "当前：" : "Now: ") + v.name + " · " + qualityLabel(v)
                                     + (currentVoiceIsDefault
                                        ? (isChinese
                                           ? "。标准音质偏机械——在 设置→辅助功能→朗读内容→声音 下载增强/高级版（英式/美式均可）"
                                           : ". Default is robotic — download an Enhanced/Premium voice in Settings → Accessibility → Spoken Content → Voices")
                                        : (isChinese ? "（高音质人声）" : " (high quality)")))
                            } icon: {
                                Image(systemName: currentVoiceIsDefault ? "exclamationmark.triangle" : "checkmark.seal.fill")
                            }
                            .font(.caption2)
                            .foregroundStyle(currentVoiceIsDefault ? .orange.opacity(0.85) : RexTheme.textDim)
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
