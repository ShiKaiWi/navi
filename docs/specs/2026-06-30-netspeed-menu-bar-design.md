# NetSpeed Menu Bar Tool — Design Spec

## Overview

A new Navi tool that displays real-time network upload/download speed in the macOS menu bar. The dashboard (main window) provides configuration for refresh frequency, network interface selection, and display unit preference.

## Requirements

- Display upload and download speed in menu bar: `↑ 1.2 MB/s ↓ 12.5 MB/s`
- Data acquisition via system network interface statistics (`getifaddrs`)
- Configurable refresh interval (default 2 seconds)
- Menu bar and main window share the same lifecycle — closing the window exits the app
- Clicking menu bar item opens/focuses main window and navigates to NetSpeed tool

## Architecture

### Implementation Approach

SwiftUI `MenuBarExtra` scene (macOS 14+ native). Keeps the project purely SwiftUI.

### Component Overview

| Component | Responsibility |
|-----------|---------------|
| `NetSpeedMonitor` | Data acquisition layer. Reads system network interface stats, computes rate deltas on timer, publishes upload/download speed |
| `NetSpeedTool` | Conforms to `Tool` protocol, registered in `ToolRegistry`, provides dashboard config view |
| `NetSpeedView` | Dashboard configuration UI: refresh frequency, interface filter, unit preference |
| `MenuBarExtra` scene | Declared in `NaviApp.swift`, uses `NetSpeedMonitor` data as label |
| `NetworkInterface` | Wraps `getifaddrs` C API, filters interfaces, returns byte counts |

### Data Flow

```
System network interfaces → NetSpeedMonitor (Timer, every N seconds)
    → @Observable uploadSpeed / downloadSpeed
        → MenuBarExtra label (formatted text)
        → NetSpeedView (live preview in dashboard)
```

`NetSpeedMonitor` is an `@Observable` class owned by `NaviApp` and shared with both the menu bar scene and the tool view.

## Data Acquisition — `NetSpeedMonitor`

### Method

Use `getifaddrs()` to read each network interface's `if_data` struct, extracting:
- `ifi_ibytes` — cumulative received bytes
- `ifi_obytes` — cumulative sent bytes

Compute rate = (current_bytes - previous_bytes) / time_interval.

### Interface Filtering

| Prefix | Meaning | Action |
|--------|---------|--------|
| `en` | Wi-Fi / Ethernet | Include |
| `pdp_ip` | Cellular | Include |
| `lo` | Loopback | Exclude |
| `bridge` / `utun` / `awdl` | Virtual | Exclude |

### Configuration Options

- **All** (default): sum all physical interfaces
- **Wi-Fi**: only `en0` (typically Wi-Fi)
- **Wired**: `en*` excluding `en0`

### Class Design

```swift
@Observable
class NetSpeedMonitor {
    var uploadSpeed: UInt64 = 0      // bytes per second
    var downloadSpeed: UInt64 = 0    // bytes per second

    // Configuration (persisted to UserDefaults)
    var refreshInterval: TimeInterval = 2.0
    var interfaceFilter: InterfaceFilter = .all
    var displayUnit: DisplayUnit = .auto
}
```

### Timer Strategy

- Use `Task.sleep` in a detached async loop, respecting `refreshInterval`
- Rebuild loop when user changes refresh frequency
- Stops automatically with app termination

## Menu Bar Display

### MenuBarExtra Declaration (in NaviApp.swift)

```swift
MenuBarExtra {
    Button("打开 Navi") {
        // activate window, navigate to NetSpeed tool
    }
    Button("退出") {
        NSApplication.shared.terminate(nil)
    }
} label: {
    Text(netSpeedMonitor.formattedSpeed)
}
```

### Formatting Rules

| Speed Range | Auto Display |
|-------------|-------------|
| 0 – 999 B/s | `↑ 0 B/s ↓ 512 B/s` |
| 1 KB/s – 999 KB/s | `↑ 15 KB/s ↓ 856 KB/s` |
| 1 MB/s – 999 MB/s | `↑ 1.2 MB/s ↓ 45.3 MB/s` |
| ≥ 1 GB/s | `↑ 1.1 GB/s ↓ 2.0 GB/s` |

- **Auto mode**: selects most appropriate unit for current speed
- **Fixed KB/s**: always display in KB/s
- **Fixed MB/s**: always display in MB/s
- Decimal places: none for KB level, 1 decimal for MB/GB level

### Zero / Disconnect Behavior

Always display `↑ 0 B/s ↓ 0 B/s` — consistent format regardless of connectivity state.

### Click Behavior

Click menu bar text → dropdown menu → "打开 Navi" button → activate main window + set `selectedToolID` to NetSpeed tool.

Window activation: `NSApplication.shared.activate(ignoringOtherApps: true)`.

## Dashboard Configuration — `NetSpeedView`

### Layout

```
NetSpeedView
├── Current Status (read-only)
│   ├── Upload:   ↑ 1.2 MB/s
│   └── Download: ↓ 12.5 MB/s
│
├── Configuration
│   ├── Refresh Interval: Picker [1s / 2s / 3s / 5s]
│   ├── Network Interface: Picker [All / Wi-Fi / Wired]
│   └── Display Unit: Picker [Auto / KB/s / MB/s]
│
└── Footer note
    └── "网速显示在菜单栏中，上方为实时预览"
```

### Persistence

`UserDefaults` with `netspeed.` key prefix:
- `netspeed.refreshInterval` → Double
- `netspeed.interfaceFilter` → String (enum raw value)
- `netspeed.displayUnit` → String (enum raw value)

Changes take effect immediately. `NetSpeedMonitor` observes config changes and updates timer/formatting.

## App Lifecycle

- App startup: main window and menu bar both appear
- Close main window: app exits, menu bar disappears
- No background-only mode — window and menu bar are co-dependent

## File Organization

```
Sources/Navi/Tools/NetSpeedTool/
├── NetSpeedTool.swift       # Tool protocol conformance (~15 lines)
├── NetSpeedView.swift       # Dashboard configuration UI
├── NetSpeedMonitor.swift    # Data acquisition + formatting logic
└── NetworkInterface.swift   # getifaddrs wrapper + interface filtering
```

### Registration

Add `NetSpeedTool()` to `ToolRegistry.tools` array in `Models/Tool.swift`.

### NaviApp.swift Changes

- Add `@State private var netSpeedMonitor = NetSpeedMonitor()`
- Add `MenuBarExtra` scene alongside existing `WindowGroup`
- Share monitor instance with both scenes via `.environment()` modifier on each scene
