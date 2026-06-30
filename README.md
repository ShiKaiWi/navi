# Navi

A macOS toolset application providing productive utilities in a unified interface.

Built with Swift and SwiftUI, targeting macOS 14+ (Sonoma).

## Tools

- **Timestamp Converter** — Convert between Unix timestamps and human-readable dates with timezone support

## Install

```bash
make install
```

The app is installed to `~/Applications/Navi.app`.

## Development

```bash
make run    # Build and run in debug mode
make build  # Debug build
make clean  # Clean build artifacts
```

## Adding a Tool

1. Create a new directory under `Sources/Navi/Tools/YourTool/`
2. Create a struct conforming to the `Tool` protocol
3. Add it to `ToolRegistry.tools` in `Sources/Navi/Models/Tool.swift`
