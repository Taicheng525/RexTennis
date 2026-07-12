import SwiftUI

/// 根视图：根据是否有进行中的比赛，在设置页与比赛页之间切换。
struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if let match = appModel.match {
                MatchView(viewModel: match)
            } else {
                SetupView()
            }
        }
        .onAppear(perform: seedForUITestingIfNeeded)
    }

    private func seedForUITestingIfNeeded() {
#if DEBUG
        guard appModel.match == nil,
              ProcessInfo.processInfo.arguments.contains("-uiPreviewMatch") else { return }
        appModel.startMatch(config: MatchConfig(targetGames: 4, firstServer: .me))
        // 预置：我方拿下第 1 局，当前局 30-15。
        appModel.match?.debugApply([.me, .me, .me, .me, .me, .me, .opponent])
#endif
    }
}

#Preview {
    ContentView().environmentObject(AppModel())
}
