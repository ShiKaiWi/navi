import SwiftUI

struct JsonizerTool: Tool {
    let id = "jsonizer"
    let name = "Jsonizer"
    let description = "Format & explore JSON"
    let icon = "curlybraces"
    let iconColor: Color = .green

    var body: AnyView {
        AnyView(JsonizerView())
    }
}
