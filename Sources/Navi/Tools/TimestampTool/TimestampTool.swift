import SwiftUI

struct TimestampTool: Tool {
    let id = "timestamp"
    let name = "Timestamp"
    let icon = "clock"

    var body: AnyView {
        AnyView(TimestampView())
    }
}
