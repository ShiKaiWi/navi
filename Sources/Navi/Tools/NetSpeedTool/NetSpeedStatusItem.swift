import AppKit
import Observation

/// Menu-bar net speed using a fixed `NSStatusItem` length.
///
/// `MenuBarExtra` always uses `NSStatusItem.variableLength` and sizes to the
/// live text, ignoring SwiftUI frames, hidden placeholders, and fonts. A
/// numeric `length` is what actually stops neighboring icons from moving.
@MainActor
final class NetSpeedStatusItem: NSObject {
    var onOpen: () -> Void

    private let monitor: NetSpeedMonitor
    private let statusItem: NSStatusItem

    init(monitor: NetSpeedMonitor, onOpen: @escaping () -> Void = {}) {
        self.monitor = monitor
        self.onOpen = onOpen
        self.statusItem = NSStatusBar.system.statusItem(withLength: NetSpeedMenuBarMetrics.itemWidth)
        super.init()
        configureMenu()
        refresh()
        observeMonitor()
    }

    @objc private func openNavi() {
        onOpen()
    }

    private func configureMenu() {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开 Navi", action: #selector(openNavi), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func observeMonitor() {
        withObservationTracking {
            _ = monitor.uploadSpeed
            _ = monitor.downloadSpeed
            _ = monitor.displayUnit
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observeMonitor()
            }
        }
    }

    private func refresh() {
        guard let button = statusItem.button else { return }
        let upload = SpeedFormat.components(bytesPerSecond: monitor.uploadSpeed, unit: monitor.displayUnit)
        let download = SpeedFormat.components(bytesPerSecond: monitor.downloadSpeed, unit: monitor.displayUnit)
        let size = NSSize(width: NetSpeedMenuBarMetrics.itemWidth, height: NSStatusBar.system.thickness)
        let image = NSImage(size: size, flipped: true) { rect in
            NetSpeedMenuBarDrawing.draw(upload: upload, download: download, in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "↑ \(SpeedFormat.display(bytesPerSecond: monitor.uploadSpeed, unit: monitor.displayUnit))  ↓ \(SpeedFormat.display(bytesPerSecond: monitor.downloadSpeed, unit: monitor.displayUnit))"
    }
}

enum NetSpeedMenuBarMetrics {
    static let fontSize: CGFloat = 9
    static let columnSpacing: CGFloat = 3
    static let horizontalPadding: CGFloat = 6

    static let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)

    static let arrowWidth = ceil(measure("↑"))
    static let valueWidth = ceil(measure("999"))
    static let unitWidth = ceil(["B/s", "KB/s", "MB/s", "GB/s", "TB/s"].map(measure).max() ?? 24)

    static let itemWidth =
        horizontalPadding * 2
        + arrowWidth
        + columnSpacing
        + valueWidth
        + columnSpacing
        + unitWidth
        + 2

    private static func measure(_ string: String) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font]).width
    }
}

enum NetSpeedMenuBarDrawing {
    static func draw(
        upload: (value: String, unit: String),
        download: (value: String, unit: String),
        in bounds: CGRect,
        color: NSColor
    ) {
        let rowHeight = bounds.height / 2
        drawRow(arrow: "↑", parts: upload, in: CGRect(x: 0, y: 0, width: bounds.width, height: rowHeight), color: color)
        drawRow(arrow: "↓", parts: download, in: CGRect(x: 0, y: rowHeight, width: bounds.width, height: rowHeight), color: color)
    }

    private static func drawRow(
        arrow: String,
        parts: (value: String, unit: String),
        in rect: CGRect,
        color: NSColor
    ) {
        let muted = color.withAlphaComponent(0.55)
        var x = NetSpeedMenuBarMetrics.horizontalPadding

        draw(arrow, in: CGRect(x: x, y: rect.minY, width: NetSpeedMenuBarMetrics.arrowWidth, height: rect.height), alignment: .center, color: muted)
        x += NetSpeedMenuBarMetrics.arrowWidth + NetSpeedMenuBarMetrics.columnSpacing

        draw(parts.value, in: CGRect(x: x, y: rect.minY, width: NetSpeedMenuBarMetrics.valueWidth, height: rect.height), alignment: .right, color: color)
        x += NetSpeedMenuBarMetrics.valueWidth + NetSpeedMenuBarMetrics.columnSpacing

        draw(parts.unit, in: CGRect(x: x, y: rect.minY, width: NetSpeedMenuBarMetrics.unitWidth, height: rect.height), alignment: .left, color: color)
    }

    private static func draw(_ string: String, in rect: CGRect, alignment: NSTextAlignment, color: NSColor) {
        let font = NetSpeedMenuBarMetrics.font
        let textSize = (string as NSString).size(withAttributes: [.font: font])
        let centered = CGRect(
            x: rect.minX,
            y: rect.minY + ((rect.height - textSize.height) / 2).rounded(.down),
            width: rect.width,
            height: textSize.height
        )
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byClipping
        (string as NSString).draw(in: centered, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ])
    }
}
