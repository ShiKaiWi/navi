import SwiftUI

struct ContentView: View {
    @Binding var selectedToolID: String?

    var body: some View {
        NavigationSplitView {
            Sidebar(tools: ToolRegistry.tools, selectedToolID: $selectedToolID)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            if let id = selectedToolID,
               let tool = ToolRegistry.tools.first(where: { $0.id == id }) {
                tool.body
            } else {
                Text("Select a tool")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
