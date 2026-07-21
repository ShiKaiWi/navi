import SwiftUI

struct ContentView: View {
    @Binding var selectedToolID: String?

    /// Cache each tool's `body` so `AnyView` is created once and reused
    /// instead of being recomputed from the protocol requirement on every
    /// render. This avoids flash / re-layout when switching tools.
    @State private var bodyCache: [String: AnyView] = [:]

    var body: some View {
        NavigationSplitView {
            Sidebar(tools: ToolRegistry.tools, selectedToolID: $selectedToolID)
                // Fixed width prevents the sidebar from resizing when the
                // detail content changes between tools with different
                // intrinsic sizes.
                .navigationSplitViewColumnWidth(220)
        } detail: {
            if let id = selectedToolID {
                cachedBody(for: id)
            } else {
                Text("Select a tool")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cachedBody(for id: String) -> AnyView {
        if let cached = bodyCache[id] { return cached }
        guard let tool = ToolRegistry.tools.first(where: { $0.id == id }) else {
            return AnyView(EmptyView())
        }
        let body = tool.body
        bodyCache[id] = body
        return body
    }
}
