import SwiftUI

/// 赛前设置：选择局数制、首发方、播报语言，然后开始比赛。
struct SetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var targetGames: Int = 4
    @State private var firstServer: Side = .me

    private var isChinese: Bool { appModel.language == .chinese }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            VStack(spacing: 6) {
                Text("🎾 RexTennis")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(isChinese ? "蓝牙耳机比分语音播报" : "Bluetooth score announcer")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 22) {
                pickerBlock(title: isChinese ? "赛制（一盘定胜负）" : "Format (single set)") {
                    Picker("", selection: $targetGames) {
                        Text(isChinese ? "4 局制" : "4 games").tag(4)
                        Text(isChinese ? "6 局制" : "6 games").tag(6)
                    }
                    .pickerStyle(.segmented)
                }

                pickerBlock(title: isChinese ? "谁先发球" : "First server") {
                    Picker("", selection: $firstServer) {
                        Text(isChinese ? "我方" : "You").tag(Side.me)
                        Text(isChinese ? "对方" : "Opponent").tag(Side.opponent)
                    }
                    .pickerStyle(.segmented)
                }

                pickerBlock(title: isChinese ? "播报语言" : "Announcement language") {
                    Picker("", selection: $appModel.language) {
                        Text("中文").tag(AnnounceLanguage.chinese)
                        Text("English").tag(AnnounceLanguage.english)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                SettingsStore.language = appModel.language
                appModel.startMatch(config: MatchConfig(targetGames: targetGames, firstServer: firstServer))
            } label: {
                Text(isChinese ? "开始比赛" : "Start match")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func pickerBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    SetupView().environmentObject(AppModel())
}
