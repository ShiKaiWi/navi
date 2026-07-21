import SwiftUI
import HighlightSwift

struct JsonizerView: View {
    @State private var input: String = ""
    @State private var mode: Mode = .tree

    /// The parse outcome, recomputed off the main render path (debounced) so a
    /// large paste doesn't re-parse on every keystroke or view update.
    @State private var parseState: ParseState = .empty
    /// Tree model is built once per successful parse and reused across renders.
    @State private var treeModel: JSONTreeModel?
    /// Pretty-printed text, cached so we don't re-serialize on every render.
    @State private var prettyText: String = ""
    /// Whether `prettyText` is small enough to syntax-highlight (computed once at
    /// parse time, not via an O(n) `String.count` on every render).
    @State private var canHighlight = false

    private enum Mode: String, CaseIterable, Identifiable {
        case tree = "Tree"
        case text = "Text"
        var id: String { rawValue }
    }

    private enum ParseState {
        case empty
        case success(JSONValue)
        case failure(String)
    }

    /// Above this size we skip syntax highlighting — HighlightSwift tokenizes the
    /// whole string on the main actor, which stalls badly on large input. Plain
    /// monospaced text stays responsive.
    private static let highlightSizeLimit = 20_000

    var body: some View {
        PanedSplitView {
            inputPane
        } trailing: {
            outputPane
        }
        .toolbar { toolbarContent }
        .navigationTitle("Jsonizer")
        // Debounced parse driven by the current input. `.task(id:)` runs on the
        // MainActor and is automatically cancelled & restarted whenever `input`
        // changes, so a stale parse can never publish over a newer one — and,
        // crucially, the @State writes happen on the main actor (unlike a bare
        // Task spawned from a nonisolated method, which silently ran off-main
        // and left SwiftUI never seeing the result).
        .task(id: input) {
            let current = input
            // Coalesce bursts of keystrokes / a big paste into one parse.
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            applyParse(of: current)
        }
    }

    // MARK: - Parsing (debounced)

    private func applyParse(of raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parseState = .empty
            treeModel = nil
            prettyText = ""
            canHighlight = false
            return
        }
        do {
            let value = try JSONParser.parse(trimmed)
            let pretty = value.prettyPrinted()
            parseState = .success(value)
            treeModel = JSONTreeModel(value: value)
            prettyText = pretty
            canHighlight = pretty.utf8.count <= Self.highlightSizeLimit
        } catch {
            parseState = .failure(error.localizedDescription)
            treeModel = nil
            prettyText = ""
            canHighlight = false
        }
    }

    // MARK: - Input

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Input")
                .font(.headline)
            PlainTextEditor(text: $input)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Paste ugly JSON here…")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            // Match PlainTextEditor's container inset (+ the 3/1
                            // wrapper padding) so it sits on the cursor.
                            .padding(.leading, PlainTextEditor.textInset.width + 3)
                            .padding(.top, PlainTextEditor.textInset.height + 1)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding()
    }

    // MARK: - Output

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output")
                    .font(.headline)
                Spacer()
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            outputContent
        }
        .padding()
    }

    @ViewBuilder
    private var outputContent: some View {
        switch parseState {
        case .success:
            switch mode {
            case .tree:
                if let treeModel {
                    JSONTreeView(model: treeModel)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                }
            case .text:
                textOutput
            }
        case .empty:
            emptyView
        case .failure(let message):
            errorView(message)
        }
    }

    @ViewBuilder
    private var textOutput: some View {
        ScrollView([.vertical, .horizontal]) {
            Group {
                if canHighlight {
                    CodeText(prettyText, language: "json")
                        .textSelection(.enabled)
                } else {
                    // Too large to highlight responsively — show plain text.
                    Text(prettyText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "curlybraces")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Paste JSON on the left to format and explore it.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Invalid JSON", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.headline)
            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                treeModel?.expandAll()
            } label: {
                Label("Expand All", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            .help("Expand all nodes")
            .disabled(mode != .tree || treeModel == nil)

            Button {
                treeModel?.collapseAll()
            } label: {
                Label("Collapse All", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .help("Collapse all nodes")
            .disabled(mode != .tree || treeModel == nil)

            Divider()

            Button {
                copyFormatted()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .help("Copy formatted JSON")
            .disabled(prettyText.isEmpty)

            Button {
                input = JsonizerView.sample
            } label: {
                Label("Sample", systemImage: "sparkles")
            }
            .help("Load sample JSON")

            Button(role: .destructive) {
                input = ""
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear input")
            .disabled(input.isEmpty)
        }
    }

    private func copyFormatted() {
        guard !prettyText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prettyText, forType: .string)
    }

    private static let sample = """
    {"name":"Navi","version":1.2,"active":true,"tags":["dev","tools","json"],"owner":{"id":42,"email":"ada@example.com","roles":["admin","user"]},"metadata":null}
    """
}

// MARK: - Split View

private let kSplitDividerWidth: CGFloat = 8
private let kSplitMinRatio: CGFloat = 0.2
private let kSplitMaxRatio: CGFloat = 0.8

/// A resizable two-pane horizontal split view built entirely in SwiftUI.
///
/// Unlike `HSplitView` (which wraps `NSSplitView`), this view is a simple
/// `HStack` with a draggable divider. It cooperates with the parent layout
/// and doesn't impose an intrinsic minimum size — so it works correctly
/// inside a `NavigationSplitView` without changing the sidebar width.
struct PanedSplitView<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    @State private var ratio: CGFloat = 0.45

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { proxy in
            let available = proxy.size.width
            let leftWidth = max(0, available * ratio - kSplitDividerWidth / 2)
            let rightWidth = max(0, available * (1 - ratio) - kSplitDividerWidth / 2)

            HStack(spacing: 0) {
                leading
                    .frame(width: leftWidth)
                    .clipped()

                DividerHandle(ratio: $ratio)

                trailing
                    .frame(width: rightWidth)
                    .clipped()
            }
        }
    }
}

/// A draggable divider that adjusts the split ratio.
private struct DividerHandle: View {
    @Binding var ratio: CGFloat
    @State private var dragStartRatio: CGFloat = 0

    var body: some View {
        Color.primary
            .opacity(0.1)
            .frame(width: kSplitDividerWidth)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation.width.magnitude < 1
                            && value.translation.height.magnitude < 1
                        {
                            dragStartRatio = ratio
                        }
                        guard let sceneWidth = NSApp.keyWindow?.contentView?.bounds.width,
                              sceneWidth > 0
                        else { return }
                        let delta = value.translation.width / sceneWidth
                        let newRatio = dragStartRatio + delta
                        ratio = newRatio.clamped(to: kSplitMinRatio...kSplitMaxRatio)
                    }
            )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
