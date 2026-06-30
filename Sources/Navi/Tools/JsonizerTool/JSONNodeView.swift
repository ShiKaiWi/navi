import SwiftUI

/// A node in the rendered JSON tree.
///
/// The whole document is converted into `JSONNode`s once (cheap object
/// allocation), then only the *visible* nodes are flattened into rows and
/// rendered in a `LazyVStack`. This keeps large documents responsive: a 64 KB
/// payload with thousands of nodes no longer instantiates thousands of nested
/// `DisclosureGroup` views up front.
final class JSONNode: Identifiable {
    enum Label {
        case root
        case key(String)
        case index(Int)
    }

    let id: Int
    let label: Label
    let value: JSONValue
    let depth: Int
    let children: [JSONNode]

    var isContainer: Bool { !children.isEmpty || value.isContainer }

    init(id: Int, label: Label, value: JSONValue, depth: Int, children: [JSONNode]) {
        self.id = id
        self.label = label
        self.value = value
        self.depth = depth
        self.children = children
    }
}

/// Builds the node tree, tracks per-node expansion, and exposes the flattened
/// list of currently-visible rows.
@MainActor
final class JSONTreeModel: ObservableObject {
    /// A single rendered line. An expanded container emits two rows: its opening
    /// line (`"key": {`) before its children, and a closing line (`}`) after
    /// them — so the brackets are balanced in the flattened output.
    struct Row: Identifiable {
        enum Kind { case node, close }
        let node: JSONNode
        let kind: Kind
        // node ids are unique; shift to carve out a separate id space for the
        // closing row of the same node.
        var id: Int { kind == .node ? node.id << 1 : node.id << 1 | 1 }
    }

    let root: JSONNode
    /// Recomputed only when expansion changes — not on every view render.
    @Published private(set) var visibleRows: [Row] = []

    private var expanded: Set<Int>
    private let containerIDs: [Int]

    init(value: JSONValue) {
        var counter = 0
        var containers: [Int] = []

        func build(label: JSONNode.Label, value: JSONValue, depth: Int) -> JSONNode {
            let id = counter
            counter += 1
            var children: [JSONNode] = []
            switch value {
            case .object(let members):
                containers.append(id)
                children = members.map {
                    build(label: .key($0.key), value: $0.value, depth: depth + 1)
                }
            case .array(let items):
                containers.append(id)
                children = items.enumerated().map { idx, item in
                    build(label: .index(idx), value: item, depth: depth + 1)
                }
            default:
                break
            }
            return JSONNode(id: id, label: label, value: value, depth: depth, children: children)
        }

        root = build(label: .root, value: value, depth: 0)
        containerIDs = containers
        // Default: everything expanded.
        expanded = Set(containers)
        rebuild()
    }

    func isExpanded(_ node: JSONNode) -> Bool {
        expanded.contains(node.id)
    }

    func toggle(_ node: JSONNode) {
        guard node.isContainer else { return }
        if expanded.contains(node.id) {
            expanded.remove(node.id)
        } else {
            expanded.insert(node.id)
        }
        rebuild()
    }

    func expandAll() {
        expanded = Set(containerIDs)
        rebuild()
    }

    func collapseAll() {
        // Keep the root open so the user still sees the top level.
        expanded = [root.id]
        rebuild()
    }

    /// Walks the tree, emitting a row for each visible node (children of a
    /// collapsed container are skipped). Expanded containers also emit a
    /// trailing closing-bracket row after their children.
    private func rebuild() {
        var rows: [Row] = []
        rows.reserveCapacity(visibleRows.count)

        func walk(_ node: JSONNode) {
            rows.append(Row(node: node, kind: .node))
            if node.isContainer && expanded.contains(node.id) {
                for child in node.children { walk(child) }
                rows.append(Row(node: node, kind: .close))
            }
        }
        walk(root)
        visibleRows = rows
    }
}

/// The scrollable, lazily-rendered JSON tree.
struct JSONTreeView: View {
    @ObservedObject var model: JSONTreeModel

    var body: some View {
        // A bidirectional ScrollView centers content that's smaller than the
        // viewport. To pin the tree to the top-leading corner we read the
        // viewport size and force the content to be *at least* that big via
        // minWidth/minHeight (a maxWidth/.infinity frame doesn't help here:
        // the scroll axes propose an unbounded size, so it never forces a
        // minimum). Rows wider/taller than the viewport overflow and scroll.
        GeometryReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(model.visibleRows) { row in
                        // Pass expansion as a plain value and toggling as a closure
                        // so rows don't each observe the whole model. Otherwise a
                        // single tap would invalidate every row on screen via the
                        // model's `objectWillChange` (observation fan-out).
                        JSONRowView(
                            node: row.node,
                            kind: row.kind,
                            isExpanded: model.isExpanded(row.node),
                            toggle: { model.toggle(row.node) }
                        )
                    }
                }
                .padding(8)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
            }
        }
    }
}

/// A single row: indentation, an optional disclosure chevron for containers,
/// the key/index label, and the value (or a collapsed summary).
private struct JSONRowView: View {
    let node: JSONNode
    let kind: JSONTreeModel.Row.Kind
    let isExpanded: Bool
    let toggle: () -> Void

    private static let indentWidth: CGFloat = 16

    var body: some View {
        Group {
            if kind == .close {
                closeRow
            } else {
                openRow
            }
        }
        .padding(.leading, CGFloat(node.depth) * Self.indentWidth)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isContainer { toggle() }
        }
    }

    // The opening line: chevron (for containers), key/index label, value or
    // opening bracket.
    private var openRow: some View {
        // Indent via leading padding rather than a clear-frame spacer: a
        // zero-height spacer in a baseline-aligned HStack distorts row
        // geometry. Plain padding keeps every row a uniform height.
        HStack(alignment: .center, spacing: 4) {
            if node.isContainer {
                chevron
            } else {
                // Align leaf rows with the chevron column.
                Color.clear.frame(width: 12, height: 12)
            }

            labelText
            valueText
        }
    }

    // The closing line for an expanded container: just the closing bracket,
    // aligned with the container's opening line.
    private var closeRow: some View {
        HStack(alignment: .center, spacing: 4) {
            Color.clear.frame(width: 12, height: 12)
            Text(node.value.brackets.1)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: 12, height: 12)
    }

    @ViewBuilder
    private var labelText: some View {
        switch node.label {
        case .key(let key):
            (Text(JSONValue.encodeString(key)).foregroundColor(.blue)
                + Text(":").foregroundColor(.secondary))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        case .index(let idx):
            Text("\(idx)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        case .root:
            EmptyView()
        }
    }

    @ViewBuilder
    private var valueText: some View {
        switch node.value {
        case .object, .array:
            // Containers: open bracket when expanded, summary when collapsed.
            let (open, close) = node.value.brackets
            if isExpanded {
                Text(open)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Text("\(open) … \(close)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(node.value.itemCountLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        default:
            let (text, color) = node.value.scalarDisplay
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Display helpers

private extension JSONValue {
    var brackets: (String, String) {
        switch self {
        case .object: ("{", "}")
        case .array: ("[", "]")
        default: ("", "")
        }
    }

    var itemCountLabel: String {
        let count: Int
        switch self {
        case .object(let m): count = m.count
        case .array(let a): count = a.count
        default: return ""
        }
        return count == 1 ? "1 item" : "\(count) items"
    }

    /// Display string and color for a scalar value.
    var scalarDisplay: (String, Color) {
        switch self {
        case .string(let s): (JSONValue.encodeString(s), .red)
        case .number(let n): (n, .purple)
        case .bool(let b): (b ? "true" : "false", .orange)
        case .null: ("null", .secondary)
        case .object, .array: ("", .primary)
        }
    }
}
