import SwiftUI

/// 引导用户在 iOS「设置」里下载高音质系统人声。
/// iOS 没有任何 API 允许 App 代为下载/安装人声，也不允许直接跳到辅助功能页；
/// 唯一能做的是把路径讲清楚，并提供一个打开「设置」App 的入口。
struct VoiceInstallGuideView: View {
    let language: AnnounceLanguage
    let umpire: UmpireVoice
    @Environment(\.dismiss) private var dismiss

    private var zh: Bool { language == .chinese }

    /// 目标语言在 iOS 设置里的显示名。
    private var settingsLanguageName: String {
        language == .chinese ? (zh ? "中文（中国大陆）" : "Chinese (China mainland)")
                             : (zh ? "英语（英国）" : "English (UK)")
    }

    /// 推荐的具体人声名（系统内置，标着「增强」/「高级」的版本）。
    /// 推荐的具体人声名（2026-09 在 iOS 真机核实存在）。App 会自动挑所选性别里音质最高、
    /// 且优先教程推荐的那一个，所以每种性别装**一个**就够了。
    private var recommendedVoices: String {
        switch (language, umpire) {
        case (.chinese, .female): return zh ? "丽丽 / Lili（高级）" : "Lili (Premium)"
        case (.chinese, .male):   return zh ? "汉 / Han（高级）" : "Han (Premium)"
        case (.english, .female): return zh ? "Kate（增强 / Enhanced）" : "Kate (Enhanced)"
        case (.english, .male):   return zh ? "Jamie（高级 / Premium）" : "Jamie (Premium)"
        }
    }

    private var steps: [String] {
        zh ? [
            "打开 iPhone 的「设置」",
            "进入「辅助功能」→「朗读内容」",
            "点「声音」→ 选「\(settingsLanguageName)」",
            "找到 \(recommendedVoices)，点右侧下载图标（100–300 MB，建议连 Wi‑Fi）。每种性别装一个「高级」或「增强」的就够",
            "下载完成后回到 RexTennis，自动生效，无需重启"
        ] : [
            "Open the iPhone Settings app",
            "Go to Accessibility → Spoken Content",
            "Tap Voices → \(settingsLanguageName)",
            "Find \(recommendedVoices) and tap the download icon (100–300 MB, Wi‑Fi recommended). One Premium or Enhanced voice per gender is enough",
            "Come back to RexTennis — it picks up the new voice automatically"
        ]
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(zh ? "安装高音质人声" : "Install a better voice")
                        .font(.system(.title2, design: .serif).weight(.bold))
                        .foregroundStyle(RexTheme.text)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(RexTheme.textDim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)
                .padding(.bottom, 6)

                Text(zh ? "iOS 自带的基础人声很机械。装一个「高级」或「增强」音质的系统人声，报分就像真人裁判。App 无法代你下载，需要在系统设置里手动装一次，只装一次即可。"
                        : "The default iOS voice sounds robotic. Install one Premium or Enhanced system voice and the umpire will sound human. Apps aren't allowed to download voices for you; you only need to do this once.")
                    .font(.system(size: 14))
                    .foregroundStyle(RexTheme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(RexTheme.accent, in: Circle())
                            Text(step)
                                .font(.system(size: 15))
                                .foregroundStyle(RexTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rexCard()

                Spacer()

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
                .buttonStyle(.plain)

                Text(zh ? "会打开本 App 的设置页；点左上角「设置」返回首页，再进「辅助功能」。"
                        : "This opens this app's settings page. Tap “Settings” top-left to go back, then Accessibility.")
                    .font(.system(size: 12))
                    .foregroundStyle(RexTheme.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
    }
}
