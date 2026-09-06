import Foundation

/// Formats a byte rate using the selected display unit.
///
/// Values never use more than three digits: at 1000 the next unit is used, and
/// a single decimal appears only while the scaled value is below 10 (`1.2`,
/// `9.9`, then `10`…`999`).
enum SpeedFormat {
    static func display(bytesPerSecond: UInt64, unit: DisplayUnit) -> String {
        let parts = components(bytesPerSecond: bytesPerSecond, unit: unit)
        return "\(parts.value) \(parts.unit)"
    }

    static func components(bytesPerSecond: UInt64, unit: DisplayUnit) -> (value: String, unit: String) {
        compact(Double(bytesPerSecond), minimum: Scale(preferred: unit))
    }

    private enum Scale: Int {
        case bytes, kilobytes, megabytes, gigabytes, terabytes

        init(preferred unit: DisplayUnit) {
            switch unit {
            case .auto: self = .bytes
            case .kbps: self = .kilobytes
            case .mbps: self = .megabytes
            }
        }

        var divisor: Double {
            switch self {
            case .bytes: 1
            case .kilobytes: 1_000
            case .megabytes: 1_000_000
            case .gigabytes: 1_000_000_000
            case .terabytes: 1_000_000_000_000
            }
        }

        var label: String {
            switch self {
            case .bytes: "B/s"
            case .kilobytes: "KB/s"
            case .megabytes: "MB/s"
            case .gigabytes: "GB/s"
            case .terabytes: "TB/s"
            }
        }

        var next: Scale? { Scale(rawValue: rawValue + 1) }
    }

    private static func compact(_ bytes: Double, minimum: Scale) -> (value: String, unit: String) {
        var scale = minimum
        var value = bytes / scale.divisor
        while let next = scale.next, value >= 999.5 {
            scale = next
            value = bytes / scale.divisor
        }
        return (formatNumber(value, isBytes: scale == .bytes), scale.label)
    }

    private static func formatNumber(_ value: Double, isBytes: Bool) -> String {
        if isBytes {
            return String(Int(value))
        }
        if value < 9.95 {
            return String(format: "%.1f", (value * 10).rounded() / 10)
        }
        return String(lround(value))
    }
}
