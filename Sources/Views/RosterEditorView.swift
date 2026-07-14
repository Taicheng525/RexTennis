import SwiftUI

/// 名单编辑：批量维护「队员名」与「队名」两份名单（每行一个名字，支持整批粘贴）。
/// 保存后，赛前每个名字框右侧的下拉即可直接选到这些名字。
struct RosterEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let isChinese: Bool

    @State private var playersText: String
    @State private var teamsText: String

    init(isChinese: Bool) {
        self.isChinese = isChinese
        _playersText = State(initialValue: SettingsStore.playerRoster.joined(separator: "\n"))
        _teamsText = State(initialValue: SettingsStore.teamRoster.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        editorSection(isChinese ? "队员名单" : "PLAYERS",
                                      text: $playersText, minHeight: 220)
                        editorSection(isChinese ? "队名名单" : "TEAM NAMES",
                                      text: $teamsText, minHeight: 120)
                        Text(isChinese ? "每行一个名字，可直接粘贴一批。保存后在赛前名字框右侧下拉里选用。"
                                       : "One name per line; paste a batch. Then pick them from the dropdown next to each name field.")
                            .font(.caption)
                            .foregroundStyle(RexTheme.textFaint)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isChinese ? "管理名单" : "Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        SettingsStore.playerRoster = parse(playersText)
                        SettingsStore.teamRoster = parse(teamsText)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(RexTheme.accent)
        .preferredColorScheme(.dark)
    }

    private func editorSection(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .tracking(1.6)
                .foregroundStyle(RexTheme.textDim)
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(RexTheme.text)
                .font(.body)
                .autocorrectionDisabled()
                .frame(minHeight: minHeight)
                .padding(10)
                .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(RexTheme.hairline, lineWidth: 1)
                )
        }
    }

    /// 按行拆分：去空白、去空行、去重，保持顺序。
    private func parse(_ s: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in s.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty && !seen.contains(t) {
                seen.insert(t)
                out.append(t)
            }
        }
        return out
    }
}
