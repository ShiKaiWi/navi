# NetSpeed Menu Bar Tool — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a NetSpeed tool to Navi that displays real-time upload/download speed in the macOS menu bar, with a dashboard for configuration.

**Architecture:** SwiftUI `MenuBarExtra` scene for menu bar display, `@Observable` class `NetSpeedMonitor` for data acquisition via `getifaddrs`, and a standard `Tool`-protocol-conforming dashboard view for configuration. The monitor is owned at the app level and shared via `.environment()`.

**Tech Stack:** Swift 5.10, SwiftUI (macOS 14+), Darwin `getifaddrs` C API, UserDefaults for persistence.

---

## File Structure

| File | Responsibility |
|------|---------------|
| Create: `Sources/Navi/Tools/NetSpeedTool/NetworkInterface.swift` | Wraps `getifaddrs` C API; returns total upload/download byte counts filtered by interface type |
| Create: `Sources/Navi/Tools/NetSpeedTool/NetSpeedMonitor.swift` | `@Observable` class: timer loop, calls NetworkInterface, computes deltas, formats display string, persists config to UserDefaults |
| Create: `Sources/Navi/Tools/NetSpeedTool/NetSpeedTool.swift` | `Tool` protocol conformance (~15 lines) |
| Create: `Sources/Navi/Tools/NetSpeedTool/NetSpeedView.swift` | Dashboard config UI: live speed preview, pickers for interval/interface/unit |
| Modify: `Sources/Navi/Models/Tool.swift` | Add `NetSpeedTool()` to `ToolRegistry.tools` |
| Modify: `Sources/Navi/NaviApp.swift` | Add `@State var netSpeedMonitor`, `MenuBarExtra` scene, environment injection |
| Modify: `Sources/Navi/Views/ContentView.swift` | Accept `selectedToolID` binding from environment for external navigation |

---

### Task 1: NetworkInterface — getifaddrs wrapper

**Files:**
- Create: `Sources/Navi/Tools/NetSpeedTool/NetworkInterface.swift`

- [ ] **Step 1: Create the InterfaceFilter enum and NetworkInterface struct**

```swift
import Foundation
import Darwin

enum InterfaceFilter: String, CaseIterable {
    case all
    case wifi
    case wired
}

struct NetworkInterface {
    struct ByteCounts {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
    }

    static func getByteCountsFiltered(by filter: InterfaceFilter) -> ByteCounts {
        var result = ByteCounts()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return result
        }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)
            if shouldInclude(interface: name, filter: filter),
               let data = addr.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self)
                result.bytesIn += UInt64(networkData.pointee.ifi_ibytes)
                result.bytesOut += UInt64(networkData.pointee.ifi_obytes)
            }
            cursor = addr.pointee.ifa_next
        }
        return result
    }

    private static func shouldInclude(interface name: String, filter: InterfaceFilter) -> Bool {
        let excluded = ["lo", "bridge", "utun", "awdl", "llw", "ap", "gif", "stf", "XHC"]
        for prefix in excluded {
            if name.hasPrefix(prefix) { return false }
        }
        switch filter {
        case .all:
            return name.hasPrefix("en") || name.hasPrefix("pdp_ip")
        case .wifi:
            return name == "en0"
        case .wired:
            return name.hasPrefix("en") && name != "en0"
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -20`
Expected: Build succeeds with no errors related to NetworkInterface.swift

- [ ] **Step 3: Commit**

```bash
git add Sources/Navi/Tools/NetSpeedTool/NetworkInterface.swift
git commit -m "feat(netspeed): add getifaddrs wrapper for network byte counts"
```

---

### Task 2: NetSpeedMonitor — data acquisition and formatting

**Files:**
- Create: `Sources/Navi/Tools/NetSpeedTool/NetSpeedMonitor.swift`

- [ ] **Step 1: Create the DisplayUnit enum and NetSpeedMonitor class**

```swift
import Foundation
import SwiftUI

enum DisplayUnit: String, CaseIterable {
    case auto
    case kbps
    case mbps

    var label: String {
        switch self {
        case .auto: "Auto"
        case .kbps: "KB/s"
        case .mbps: "MB/s"
        }
    }
}

@Observable
@MainActor
class NetSpeedMonitor {
    var uploadSpeed: UInt64 = 0
    var downloadSpeed: UInt64 = 0

    var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "netspeed.refreshInterval")
            restartMonitoring()
        }
    }
    var interfaceFilter: InterfaceFilter {
        didSet {
            UserDefaults.standard.set(interfaceFilter.rawValue, forKey: "netspeed.interfaceFilter")
        }
    }
    var displayUnit: DisplayUnit {
        didSet {
            UserDefaults.standard.set(displayUnit.rawValue, forKey: "netspeed.displayUnit")
        }
    }

    private var monitorTask: Task<Void, Never>?
    private var previousCounts: NetworkInterface.ByteCounts?

    init() {
        self.refreshInterval = UserDefaults.standard.object(forKey: "netspeed.refreshInterval") as? TimeInterval ?? 2.0
        self.interfaceFilter = InterfaceFilter(rawValue: UserDefaults.standard.string(forKey: "netspeed.interfaceFilter") ?? "") ?? .all
        self.displayUnit = DisplayUnit(rawValue: UserDefaults.standard.string(forKey: "netspeed.displayUnit") ?? "") ?? .auto
        startMonitoring()
    }

    var formattedSpeed: String {
        "\u{2191} \(format(bytes: uploadSpeed)) \u{2193} \(format(bytes: downloadSpeed))"
    }

    private func format(bytes: UInt64) -> String {
        switch displayUnit {
        case .auto:
            if bytes >= 1_000_000_000 {
                return String(format: "%.1f GB/s", Double(bytes) / 1_000_000_000)
            } else if bytes >= 1_000_000 {
                return String(format: "%.1f MB/s", Double(bytes) / 1_000_000)
            } else if bytes >= 1_000 {
                return "\(bytes / 1_000) KB/s"
            } else {
                return "\(bytes) B/s"
            }
        case .kbps:
            return "\(bytes / 1_000) KB/s"
        case .mbps:
            return String(format: "%.1f MB/s", Double(bytes) / 1_000_000)
        }
    }

    private func startMonitoring() {
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 2.0))
            }
        }
    }

    private func restartMonitoring() {
        monitorTask?.cancel()
        previousCounts = nil
        startMonitoring()
    }

    private func sample() {
        let current = NetworkInterface.getByteCountsFiltered(by: interfaceFilter)
        if let previous = previousCounts {
            let diffIn = current.bytesIn >= previous.bytesIn ? current.bytesIn - previous.bytesIn : 0
            let diffOut = current.bytesOut >= previous.bytesOut ? current.bytesOut - previous.bytesOut : 0
            let interval = UInt64(refreshInterval)
            downloadSpeed = interval > 0 ? diffIn / interval : diffIn
            uploadSpeed = interval > 0 ? diffOut / interval : diffOut
        }
        previousCounts = current
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/Navi/Tools/NetSpeedTool/NetSpeedMonitor.swift
git commit -m "feat(netspeed): add NetSpeedMonitor with timer-based sampling and formatting"
```

---

### Task 3: NetSpeedTool — Tool protocol conformance

**Files:**
- Create: `Sources/Navi/Tools/NetSpeedTool/NetSpeedTool.swift`
- Modify: `Sources/Navi/Models/Tool.swift`

- [ ] **Step 1: Create NetSpeedTool struct**

```swift
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
```

- [ ] **Step 2: Register in ToolRegistry**

In `Sources/Navi/Models/Tool.swift`, change the `tools` array to:

```swift
@MainActor
struct ToolRegistry {
    static let tools: [any Tool] = [
        TimestampTool(),
        JsonizerTool(),
        NetSpeedTool(),
    ]
}
```

- [ ] **Step 3: Create a placeholder NetSpeedView so the project compiles**

Create `Sources/Navi/Tools/NetSpeedTool/NetSpeedView.swift`:

```swift
import SwiftUI

struct NetSpeedView: View {
    var body: some View {
        Text("NetSpeed placeholder")
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -20`
Expected: Build succeeds, NetSpeed appears in tool registry

- [ ] **Step 5: Commit**

```bash
git add Sources/Navi/Tools/NetSpeedTool/NetSpeedTool.swift Sources/Navi/Tools/NetSpeedTool/NetSpeedView.swift Sources/Navi/Models/Tool.swift
git commit -m "feat(netspeed): add NetSpeedTool protocol conformance and register in ToolRegistry"
```

---

### Task 4: NaviApp — MenuBarExtra scene and shared monitor

**Files:**
- Modify: `Sources/Navi/NaviApp.swift`
- Modify: `Sources/Navi/Views/ContentView.swift`

- [ ] **Step 1: Update NaviApp.swift with MenuBarExtra and shared state**

Replace the entire file content with:

```swift
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
```

- [ ] **Step 2: Update ContentView to accept selectedToolID as a binding**

Replace `Sources/Navi/Views/ContentView.swift` with:

```swift
import SwiftUI

struct ContentView: View {
    @Binding var selectedToolID: String?

    var body: some View {
        NavigationSplitView {
            Sidebar(tools: ToolRegistry.tools, selectedToolID: $selectedToolID)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            if let id = selectedToolID,
               let tool = ToolRegistry.tools.first(where: { $0.id == id }) {
                tool.body
            } else {
                Text("Select a tool")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `swift build 2>&1 | tail -20`
Expected: Build succeeds. MenuBarExtra appears when app runs.

- [ ] **Step 4: Commit**

```bash
git add Sources/Navi/NaviApp.swift Sources/Navi/Views/ContentView.swift
git commit -m "feat(netspeed): add MenuBarExtra scene with shared monitor and navigation"
```

---

### Task 5: NetSpeedView — dashboard configuration UI

**Files:**
- Modify: `Sources/Navi/Tools/NetSpeedTool/NetSpeedView.swift`

- [ ] **Step 1: Replace placeholder with full configuration view**

Replace `Sources/Navi/Tools/NetSpeedTool/NetSpeedView.swift` with:

```swift
import SwiftUI

struct NetSpeedView: View {
    @Environment(NetSpeedMonitor.self) private var monitor

    var body: some View {
        @Bindable var monitor = monitor
        VStack(alignment: .leading, spacing: 20) {
            statusSection
            Divider()
            configSection
            Spacer()
            footerSection
        }
        .padding()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("当前网速")
                .font(.headline)
            HStack(spacing: 20) {
                SpeedLabel(direction: "↑", speed: monitor.uploadSpeed, unit: monitor.displayUnit)
                SpeedLabel(direction: "↓", speed: monitor.downloadSpeed, unit: monitor.displayUnit)
            }
            .font(.system(size: 24, weight: .medium, design: .monospaced))
        }
    }

    private var configSection: some View {
        @Bindable var monitor = monitor
        return VStack(alignment: .leading, spacing: 16) {
            Text("配置")
                .font(.headline)

            LabeledContent("刷新频率") {
                Picker("", selection: $monitor.refreshInterval) {
                    Text("1 秒").tag(1.0 as TimeInterval)
                    Text("2 秒").tag(2.0 as TimeInterval)
                    Text("3 秒").tag(3.0 as TimeInterval)
                    Text("5 秒").tag(5.0 as TimeInterval)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }

            LabeledContent("网络接口") {
                Picker("", selection: $monitor.interfaceFilter) {
                    Text("全部").tag(InterfaceFilter.all)
                    Text("Wi-Fi").tag(InterfaceFilter.wifi)
                    Text("有线").tag(InterfaceFilter.wired)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }

            LabeledContent("显示单位") {
                Picker("", selection: $monitor.displayUnit) {
                    ForEach(DisplayUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }
        }
    }

    private var footerSection: some View {
        Text("网速显示在菜单栏中，上方为实时预览")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private struct SpeedLabel: View {
    let direction: String
    let speed: UInt64
    let unit: DisplayUnit

    var body: some View {
        HStack(spacing: 4) {
            Text(direction)
                .foregroundStyle(.secondary)
            Text(formatted)
        }
    }

    private var formatted: String {
        switch unit {
        case .auto:
            if speed >= 1_000_000_000 {
                return String(format: "%.1f GB/s", Double(speed) / 1_000_000_000)
            } else if speed >= 1_000_000 {
                return String(format: "%.1f MB/s", Double(speed) / 1_000_000)
            } else if speed >= 1_000 {
                return "\(speed / 1_000) KB/s"
            } else {
                return "\(speed) B/s"
            }
        case .kbps:
            return "\(speed / 1_000) KB/s"
        case .mbps:
            return String(format: "%.1f MB/s", Double(speed) / 1_000_000)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/Navi/Tools/NetSpeedTool/NetSpeedView.swift
git commit -m "feat(netspeed): add dashboard configuration UI with live speed preview"
```

---

### Task 6: Integration test — run the app and verify end-to-end

**Files:** None (manual verification)

- [ ] **Step 1: Build and run the app**

Run: `swift build 2>&1 | tail -20`
Expected: Clean build

- [ ] **Step 2: Launch and verify menu bar**

Run: `.build/debug/Navi &`

Verify:
1. Main window opens with NetSpeed in sidebar
2. Menu bar shows `↑ 0 B/s ↓ 0 B/s` initially, then updates after first interval
3. Clicking menu bar item shows dropdown with "打开 Navi" and "退出"
4. Clicking "打开 Navi" focuses main window and selects NetSpeed tool
5. Dashboard shows live speed and three configuration pickers
6. Changing refresh interval immediately restarts the timer
7. Closing main window exits the app (menu bar disappears)

- [ ] **Step 3: Fix any issues found during testing**

Address any build or runtime issues discovered.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(netspeed): address integration test findings"
```
