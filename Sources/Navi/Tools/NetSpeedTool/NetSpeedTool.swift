import SwiftUI

struct NetSpeedTool: Tool {
    let id = "netspeed"
    let name = "NetSpeed"
    let description = "Menu bar network speed"
    let icon = "network"
    let iconColor: Color = .blue

    var body: AnyView {
        AnyView(NetSpeedView())
    }
}
