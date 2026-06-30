import SwiftUI

struct TimestampTool: Tool {
    let id = "timestamp"
    let name = "Timestamp"
    let description = "Convert between formats"
    let icon = "clock"
    let iconColor: Color = .orange

    var body: AnyView {
        AnyView(TimestampView())
    }
}
