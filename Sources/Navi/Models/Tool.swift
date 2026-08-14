import SwiftUI

protocol Tool: Identifiable, Hashable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var icon: String { get }
    var iconColor: Color { get }
    @MainActor var body: AnyView { get }
}

extension Tool {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
struct ToolRegistry {
    static let tools: [any Tool] = [
        TimestampTool(),
        JsonizerTool(),
        NetSpeedTool(),
        CommandTool(),
    ]
}
