import SwiftUI

/// 根视图：根据是否有进行中的比赛，在设置页与比赛页之间切换。
struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            if let match = appModel.match {
                MatchView(viewModel: match)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                SetupView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: appModel.match == nil)
        .onAppear(perform: seedForUITestingIfNeeded)
    }

    private func seedForUITestingIfNeeded() {
#if DEBUG
        guard appModel.match == nil else { return }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiPreviewChant") {
            appModel.startMatch(config: MatchConfig(targetGames: 4, firstServer: .me,
                                                    nameMe: "多巴胺", nameOpp: "Ace队"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak appModel] in
                appModel?.match?.cheerTeam(.me)
            }
        } else if args.contains("-uiPreviewChangeEnds") {
            appModel.startMatch(config: MatchConfig(targetGames: 4, firstServer: .me))
            // 预置：我方 4-0 拿下第 1 局 → 触发换边（对方发球）。
            appModel.match?.debugApply([.me, .me, .me, .me])
        } else if args.contains("-uiPreviewMatch") {
            appModel.startMatch(config: MatchConfig(targetGames: 4, firstServer: .me))
            // 预置：我方拿下第 1 局，当前局 30-15。
            appModel.match?.debugApply([.me, .me, .me, .me, .me, .me, .opponent])
        }
#endif
    }
}

#Preview {
    ContentView().environmentObject(AppModel())
}
