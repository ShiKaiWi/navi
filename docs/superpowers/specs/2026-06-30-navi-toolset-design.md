# Navi — macOS Toolset Application Design

## Overview

Navi is a macOS toolset application providing a collection of productive utilities in a unified interface. Built with Swift and SwiftUI, targeting macOS 14+ (Sonoma). Uses Swift Package Manager for builds with no external distribution — local build and install only.

## Architecture

### Protocol-Based Tool System

Each tool conforms to a `Tool` protocol:

```swift
protocol Tool: Identifiable, Hashable {
    var id: String { get }
    var name: String { get }
    var icon: String { get }  // SF Symbol name
    @ViewBuilder var body: some View { get }
}
```

Tools register in a central `ToolRegistry` — adding a new tool means creating a conforming type and appending it to the registry array. No changes to existing code required.

### App Shell

- `NavigationSplitView` provides the sidebar/detail split pattern (native macOS behavior: resizable sidebar, proper focus management)
- Sidebar lists all tools from the registry with icon + name
- Detail area renders the selected tool's `body` view
- Default selection is the first tool in the registry

### Project Structure

```
navi/
├── Package.swift
├── Sources/
│   └── Navi/
│       ├── NaviApp.swift              # App entry point
│       ├── Models/
│       │   └── Tool.swift             # Tool protocol + registry
│       ├── Views/
│       │   ├── ContentView.swift      # NavigationSplitView shell
│       │   └── Sidebar.swift          # Tool list sidebar
│       └── Tools/
│           └── TimestampTool/
│               ├── TimestampTool.swift # Tool conformance
│               └── TimestampView.swift # Converter UI + logic
├── Makefile
└── README.md
```

## Timestamp Converter Tool

### Behavior

**Input auto-detection:**
- If input is purely numeric (10 or 13 digits): treat as Unix timestamp (seconds or milliseconds)
- If input matches a parseable date string: treat as date and convert to timestamp
- Results update live as the user types (no submit button)

**Timezone handling:**
- Dropdown selector listing all system-known timezones
- Defaults to the user's system local timezone
- Changing timezone re-renders the output immediately

**Output:**
- ISO 8601 format: `2024-01-23T18:13:20.000+08:00`
- Copy button to clipboard
- When input is a timestamp: shows the formatted date
- When input is a date: shows the Unix timestamp (milliseconds)

**Current time reference:**
- Footer section showing the current Unix timestamp and its ISO 8601 equivalent
- Updates every second

### Detection Logic

```
Input is numeric AND 10 digits → Unix seconds
Input is numeric AND 13 digits → Unix milliseconds
Input is numeric AND other lengths → attempt as seconds, show warning if out of reasonable range
Otherwise → attempt date parsing (ISO 8601, common formats)
```

## Build System

### Package.swift

- Swift tools version: 5.10
- Platform: macOS 14+
- Single executable target `Navi`
- No external dependencies

### Makefile

```makefile
build:          swift build
release:        swift build -c release
install:        # builds release, copies .app bundle to ~/Applications
run:            swift run
clean:          swift package clean
```

### Install Procedure

```bash
git clone <repo>
cd navi
make install
# App available at ~/Applications/Navi.app
# Or: make run (for development)
```

## UI Details

- Window style: standard macOS window with title bar
- Sidebar width: ~200px, resizable via native NavigationSplitView behavior
- Color scheme: follows system appearance (light/dark mode)
- Typography: system default (SF Pro)
- Minimum window size: 600x400

## Constraints

- No external dependencies (Foundation + SwiftUI only)
- No network access required
- No sandboxing (local install, not App Store)
- macOS 14+ only (enables @Observable, latest SwiftUI features)
