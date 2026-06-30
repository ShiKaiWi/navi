import SwiftUI

@main
struct NaviApp: App {
    @State private var netSpeedMonitor = NetSpeedMonitor()
    @State private var selectedToolID: String? = ToolRegistry.tools.first?.id

    var body: some Scene {
        WindowGroup {
            ContentView(selectedToolID: $selectedToolID)
                .frame(minWidth: 600, minHeight: 400)
                .environment(netSpeedMonitor)
        }
        MenuBarExtra {
            Button("打开 Navi") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                selectedToolID = "netspeed"
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Text(netSpeedMonitor.formattedSpeed)
        }
    }
}
