import SwiftUI

struct ContentView: View {
    @Binding var selectedToolID: String?

    var body: some View {
        NavigationSplitView {
            Sidebar(tools: ToolRegistry.tools, selectedToolID: $selectedToolID)
                // Fixed width prevents the sidebar from resizing when the
                // detail content changes between tools with different
                // intrinsic sizes.
                .navigationSplitViewColumnWidth(220)
        } detail: {
            if let id = selectedToolID,
               let tool = ToolRegistry.tools.first(where: { $0.id == id }) {
                tool.body
                    // Give each tool a stable identity so SwiftUI diffs the
                    // detail as a swap of one identified subtree for another,
                    // rather than re-deriving identity from the erased
                    // `AnyView` type on every render.
                    .id(id)
            } else {
                Text("Select a tool")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
