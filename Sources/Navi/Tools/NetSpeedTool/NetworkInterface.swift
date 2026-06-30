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
