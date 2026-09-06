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
