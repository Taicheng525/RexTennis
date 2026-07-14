import SwiftUI

/// 名单管理：把「队员名」和「队名」当作一条条独立条目来增删。
/// 上方输入框逐个添加（回车即入列，可连续快速录入），点条目右侧 ⊖ 删除；
/// 保存后，赛前每个名字框右侧的下拉即可直接选到这些名字。
struct RosterEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let isChinese: Bool

    private enum Mode: Hashable { case players, teams }
    @State private var mode: Mode = .players
    @State private var players: [String]
    @State private var teams: [String]
    @State private var draft: String = ""
    @FocusState private var addFocused: Bool

    init(isChinese: Bool) {
        self.isChinese = isChinese
        _players = State(initialValue: SettingsStore.playerRoster)
        _teams = State(initialValue: SettingsStore.teamRoster)
    }

    private var list: [String] { mode == .players ? players : teams }
    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespaces) }
    private var placeholder: String {
        mode == .players ? (isChinese ? "输入队员名，回车添加" : "Player name, then return")
                         : (isChinese ? "输入队名，回车添加" : "Team name, then return")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    Picker("", selection: $mode.animation(.snappy(duration: 0.2))) {
                        Text(isChinese ? "队员" : "Players").tag(Mode.players)
                        Text(isChinese ? "队名" : "Teams").tag(Mode.teams)
                    }
                    .pickerStyle(.segmented)

                    addRow

                    if list.isEmpty {
                        emptyHint
                    } else {
                        HStack {
                            Text(isChinese ? "共 \(list.count) 个" : "\(list.count) total")
                                .font(.caption).foregroundStyle(RexTheme.textFaint)
                            Spacer()
                        }
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(list, id: \.self) { name in
                                    row(name)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle(isChinese ? "管理名单" : "Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        appendCurrent()
                        SettingsStore.playerRoster = players
                        SettingsStore.teamRoster = teams
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(RexTheme.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - 添加行（输入 + ＋）

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("", text: $draft,
                      prompt: Text(placeholder).foregroundStyle(RexTheme.textFaint))
                .foregroundStyle(RexTheme.text)
                .font(.body.weight(.medium))
                .focused($addFocused)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { appendCurrent(); addFocused = true }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(addFocused ? RexTheme.accent.opacity(0.7) : RexTheme.hairline, lineWidth: 1)
                )

            Button {
                appendCurrent(); addFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(trimmedDraft.isEmpty ? RexTheme.textFaint : RexTheme.accent)
            }
            .buttonStyle(.plain)
            .disabled(trimmedDraft.isEmpty)
        }
    }

    // MARK: - 单条名字

    private func row(_ name: String) -> some View {
        HStack {
            Text(name)
                .foregroundStyle(RexTheme.text)
                .font(.body)
            Spacer()
            Button { remove(name) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(RexTheme.textFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(RexTheme.hairline, lineWidth: 1)
        )
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 34))
                .foregroundStyle(RexTheme.textFaint)
            Text(isChinese ? "还没有名字。在上面输入，回车逐个添加。"
                           : "No names yet. Type above, press return to add.")
                .font(.callout)
                .foregroundStyle(RexTheme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    // MARK: - 增删（新名字插到最前，最近用的在上面；去重）

    private func appendCurrent() {
        let t = trimmedDraft
        guard !t.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            if mode == .players {
                if !players.contains(t) { players.insert(t, at: 0) }
            } else {
                if !teams.contains(t) { teams.insert(t, at: 0) }
            }
        }
        draft = ""
    }

    private func remove(_ name: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if mode == .players { players.removeAll { $0 == name } }
            else { teams.removeAll { $0 == name } }
        }
    }
}
