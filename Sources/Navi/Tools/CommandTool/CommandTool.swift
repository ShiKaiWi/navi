import SwiftUI

struct CommandTool: Tool {
    let id = "commands"
    let name = "Commands"
    let description = "收藏并搜索常用命令"
    let icon = "terminal"
    let iconColor: Color = .purple

    var body: AnyView {
        AnyView(CommandView())
    }
}
