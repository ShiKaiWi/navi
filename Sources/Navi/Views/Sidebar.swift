import SwiftUI

struct Sidebar: View {
    let tools: [any Tool]
    @Binding var selectedToolID: String?

    var body: some View {
        List(selection: $selectedToolID) {
            ForEach(tools, id: \.id) { tool in
                Label(tool.name, systemImage: tool.icon)
                    .tag(tool.id)
            }
        }
        .navigationTitle("Navi")
    }
}
