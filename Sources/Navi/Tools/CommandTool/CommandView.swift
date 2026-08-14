import SwiftUI

struct CommandView: View {
    @State private var store = CommandStore()
    @State private var query = ""
    @State private var showingEditor = false
    @State private var editingEntry: CommandEntry?
    @State private var copiedEntryID: UUID?

    private var results: [CommandEntry] {
        CommandSearch.search(query, in: store.entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
        .navigationTitle("Commands")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingEntry = nil
                    showingEditor = true
                } label: {
                    Label("新增命令", systemImage: "plus")
                }
                .help("新增命令")
            }
        }
        .sheet(isPresented: $showingEditor) {
            CommandEditorView(entry: editingEntry, store: store) { entry in
                if editingEntry == nil {
                    store.add(command: entry.command, keywords: entry.keywords)
                } else {
                    store.update(entry)
                }
            }
        }
        .task(id: copiedEntryID) {
            // Clear the "已复制" hint shortly after it appears.
            guard copiedEntryID != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copiedEntryID = nil
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索命令或关键词…", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if store.entries.isEmpty {
            ContentUnavailableView(
                "还没有收藏命令",
                systemImage: "terminal",
                description: Text("点击右上角 + 添加第一条命令")
            )
        } else if results.isEmpty {
            ContentUnavailableView(
                "没有匹配结果",
                systemImage: "magnifyingglass",
                description: Text("试试其他关键词")
            )
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(results) { entry in
                    CommandRow(
                        entry: entry,
                        isCopied: copiedEntryID == entry.id,
                        onCopy: { copy(entry) },
                        onEdit: {
                            editingEntry = entry
                            showingEditor = true
                        },
                        onDelete: { store.delete(entry) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private func copy(_ entry: CommandEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.command, forType: .string)
        copiedEntryID = entry.id
    }
}

private struct CommandRow: View {
    let entry: CommandEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.command)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if isHovered {
                    actions
                }
            }
            if !entry.keywords.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(entry.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Color.secondary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .background(
            isHovered ? Color.primary.opacity(0.04) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onTapGesture { onCopy() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovering }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if isCopied {
                Text("已复制")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("复制命令")

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("编辑")

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("删除")
        }
    }
}
