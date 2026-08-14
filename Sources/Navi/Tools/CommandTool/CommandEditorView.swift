import SwiftUI

/// Add/edit sheet for a single command. `entry == nil` means "new".
struct CommandEditorView: View {
    let entry: CommandEntry?
    let store: CommandStore
    let onSave: (CommandEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var command: String
    @State private var keywords: [String]
    @State private var keywordInput: String = ""

    init(entry: CommandEntry?, store: CommandStore, onSave: @escaping (CommandEntry) -> Void) {
        self.entry = entry
        self.store = store
        self.onSave = onSave
        _command = State(initialValue: entry?.command ?? "")
        _keywords = State(initialValue: entry?.keywords ?? [])
    }

    private var trimmedCommand: String {
        command.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedKeyword: String {
        keywordInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when another entry already uses this exact command text.
    private var isDuplicate: Bool {
        let target = trimmedCommand.lowercased()
        guard !target.isEmpty else { return false }
        return store.entries.contains {
            $0.id != entry?.id && $0.command.lowercased() == target
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry == nil ? "新增命令" : "编辑命令")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                Text("命令")
                    .font(.headline)
                TextField("例如: git log --oneline --graph", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                if isDuplicate {
                    Label("已存在相同命令,仍可保存", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Keywords")
                    .font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(keywords, id: \.self) { keyword in
                        keywordChip(keyword)
                    }
                }
                HStack(spacing: 6) {
                    TextField("输入关键词后回车", text: $keywordInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addKeyword)
                    Button("添加") { addKeyword() }
                        .disabled(trimmedKeyword.isEmpty)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedCommand.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 340)
    }

    private func keywordChip(_ keyword: String) -> some View {
        HStack(spacing: 4) {
            Text(keyword)
            Button {
                keywords.removeAll { $0 == keyword }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("移除关键词")
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func addKeyword() {
        let trimmed = trimmedKeyword
        guard !trimmed.isEmpty else { return }
        if !keywords.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            keywords.append(trimmed)
        }
        keywordInput = ""
    }

    private func save() {
        let trimmed = trimmedCommand
        guard !trimmed.isEmpty else { return }
        onSave(CommandEntry(id: entry?.id ?? UUID(), command: trimmed, keywords: keywords))
        dismiss()
    }
}
