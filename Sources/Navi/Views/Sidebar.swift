import SwiftUI

struct Sidebar: View {
    let tools: [any Tool]
    @Binding var selectedToolID: String?
    @State private var hoveredToolID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            toolList
        }
        .background(.background)
    }

    private var header: some View {
        Text("Tools")
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
    }

    private var toolList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(tools, id: \.id) { tool in
                    ToolRow(
                        tool: tool,
                        isSelected: selectedToolID == tool.id,
                        isHovered: hoveredToolID == tool.id
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedToolID = tool.id
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveredToolID = hovering ? tool.id : nil
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct ToolRow: View {
    let tool: any Tool
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView
            textContent
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconView: some View {
        Image(systemName: tool.icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tool.iconColor.gradient, in: RoundedRectangle(cornerRadius: 7))
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(tool.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Text(tool.description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            Color.accentColor.opacity(0.12)
        } else if isHovered {
            Color.primary.opacity(0.04)
        } else {
            Color.clear
        }
    }
}
