import SwiftUI

@main
struct NaviApp: App {
    @State private var session = NaviSession()

    var body: some Scene {
        WindowGroup {
            ContentView(selectedToolID: $session.selectedToolID)
                .frame(minWidth: 600, minHeight: 400)
                .environment(session.monitor)
        }
    }
}

@Observable
@MainActor
final class NaviSession {
    var selectedToolID: String? = ToolRegistry.tools.first?.id
    let monitor: NetSpeedMonitor
    @ObservationIgnored private let statusItem: NetSpeedStatusItem

    init() {
        let monitor = NetSpeedMonitor()
        self.monitor = monitor
        let statusItem = NetSpeedStatusItem(monitor: monitor)
        self.statusItem = statusItem
        statusItem.onOpen = { [weak self] in
            NSApplication.shared.activate(ignoringOtherApps: true)
            self?.selectedToolID = "netspeed"
        }
    }
}
