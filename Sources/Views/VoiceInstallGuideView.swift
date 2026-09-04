import SwiftUI

/// 引导用户在 iOS「设置」里下载高音质系统人声。
/// iOS 没有任何 API 允许 App 代为下载/安装人声，也不允许直接跳到辅助功能页；
/// 能做的是把「装哪 4 个、在哪装」讲清楚，并提供一个打开「设置」App 的入口。
///
/// 页面结构（自上而下、一屏放完）：一句话为什么 → 4 个推荐人声表 → 路径 → 小技巧 → 打开设置。
struct VoiceInstallGuideView: View {
    let language: AnnounceLanguage
    let umpire: UmpireVoice   // 保留参数以兼容调用方；推荐表不再按性别裁剪
    @Environment(\.dismiss) private var dismiss

    private var zh: Bool { language == .chinese }

    /// 推荐人声（2026-09 在 iOS 真机核实存在）。App 会在所选性别里优先挑这一个，
    /// 所以每种语言每种性别装一个就够。
    private struct Row { let lang: String; let path: String; let female: String; let male: String }
    private var rows: [Row] {
        zh ? [
            Row(lang: "英文", path: "英语 › 英语（英国）", female: "Kate（增强）", male: "Jamie（高级）"),
            Row(lang: "中文", path: "中文 › 中文（中国大陆）", female: "丽丽（高级）", male: "汉（高级）"),
        ] : [
            Row(lang: "English", path: "English › English (UK)", female: "Kate (Enhanced)", male: "Jamie (Premium)"),
            Row(lang: "Chinese", path: "Chinese › Chinese (China mainland)", female: "Lili (Premium)", male: "Han (Premium)"),
        ]
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 18) {
                header

                Text(zh ? "系统自带的人声很机械。装一次高音质人声，裁判就像真人。App 无法代装，需要你在系统设置里下载。"
                        : "The built-in voice sounds robotic. Install high-quality voices once and the umpire sounds human. Apps can't do this for you.")
                    .font(.system(size: 15))
                    .foregroundStyle(RexTheme.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                voiceTable
                pathCard
                tipCard

                Spacer(minLength: 0)

                openSettingsButton
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 区块

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(zh ? "安装高音质人声" : "Install better voices")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(RexTheme.text)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RexTheme.textDim)
                    .frame(width: 32, height: 32)
                    .background(RexTheme.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(zh ? "关闭" : "Close")
        }
    }

    /// 要下载的 4 个人声：两行（语言）× 两列（女声 / 男声）。
    private var voiceTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(zh ? "下载这 4 个" : "DOWNLOAD THESE 4")
                .padding(.bottom, 12)
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(row.lang)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(RexTheme.text)
                        Text(row.path)
                            .font(.system(size: 12))
                            .foregroundStyle(RexTheme.textFaint)
                    }
                    HStack(spacing: 10) {
                        voiceCell(zh ? "女声" : "FEMALE", row.female)
                        voiceCell(zh ? "男声" : "MALE", row.male)
                    }
                }
                .padding(.vertical, 12)
                if i < rows.count - 1 {
                    Rectangle().fill(RexTheme.hairline).frame(height: 1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rexCard()
    }

    private func voiceCell(_ label: String, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(RexTheme.textFaint)
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RexTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 在哪下载：一条面包屑 + 一句操作。
    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(zh ? "在哪里" : "WHERE")
            HStack(spacing: 6) {
                ForEach(Array((zh ? ["设置", "辅助功能", "朗读内容", "声音"]
                                  : ["Settings", "Accessibility", "Spoken Content", "Voices"]).enumerated()),
                        id: \.offset) { i, s in
                    if i > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RexTheme.textFaint)
                    }
                    Text(s)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RexTheme.text)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
            Text(zh ? "进对应语言，点人声右侧的下载图标（100–300 MB，建议连 Wi‑Fi）。装完回到 RexTennis 自动生效。"
                    : "Open the language, tap the download icon next to the voice (100–300 MB, Wi‑Fi recommended). RexTennis picks it up automatically.")
                .font(.system(size: 13))
                .foregroundStyle(RexTheme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rexCard()
    }

    /// 方言彩蛋：系统级设置，App 无法控制，但可以玩。
    private var tipCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RexTheme.accent)
                .padding(.top, 2)
            Text(zh ? "想听裁判说东北话？「中文」页里把「朗读语言」切成方言即可，改回「普通话」恢复。"
                    : "Want the umpire in a Chinese dialect? On the Chinese page switch “Spoken Language” to a dialect; set it back to Mandarin to undo.")
                .font(.system(size: 13))
                .foregroundStyle(RexTheme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RexTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(RexTheme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private var openSettingsButton: some View {
        VStack(spacing: 8) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(zh ? "打开「设置」" : "Open Settings")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(RexTheme.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [RexTheme.green, RexTheme.green.opacity(0.75)],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(RexTheme.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            Text(zh ? "会落在本 App 的设置页，点左上角「设置」回到首页再进「辅助功能」"
                    : "Lands on this app's settings page — tap “Settings” top-left, then Accessibility")
                .font(.system(size: 12))
                .foregroundStyle(RexTheme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .serif))
            .tracking(1.8)
            .foregroundStyle(RexTheme.textDim)
    }
}
