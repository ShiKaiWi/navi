import Testing
@testable import Navi

struct SpeedFormatTests {
    @Test func autoUsesNextUnitAtOneThousand() {
        #expect(SpeedFormat.display(bytesPerSecond: 0, unit: .auto) == "0 B/s")
        #expect(SpeedFormat.display(bytesPerSecond: 512, unit: .auto) == "512 B/s")
        #expect(SpeedFormat.display(bytesPerSecond: 999, unit: .auto) == "999 B/s")
        #expect(SpeedFormat.display(bytesPerSecond: 1_000, unit: .auto) == "1.0 KB/s")
        #expect(SpeedFormat.display(bytesPerSecond: 1_500, unit: .auto) == "1.5 KB/s")
        #expect(SpeedFormat.display(bytesPerSecond: 15_000, unit: .auto) == "15 KB/s")
        #expect(SpeedFormat.display(bytesPerSecond: 1_200_000, unit: .auto) == "1.2 MB/s")
        #expect(SpeedFormat.display(bytesPerSecond: 12_500_000, unit: .auto) == "13 MB/s")
        #expect(SpeedFormat.display(bytesPerSecond: 1_100_000_000, unit: .auto) == "1.1 GB/s")
    }

    @Test func fixedUnitsAlsoPromoteAtOneThousand() {
        #expect(SpeedFormat.components(bytesPerSecond: 15_000, unit: .kbps) == ("15", "KB/s"))
        #expect(SpeedFormat.components(bytesPerSecond: 5_000_000, unit: .kbps) == ("5.0", "MB/s"))
        #expect(SpeedFormat.components(bytesPerSecond: 1_200_000, unit: .mbps) == ("1.2", "MB/s"))
        #expect(SpeedFormat.components(bytesPerSecond: 1_200_000_000, unit: .mbps) == ("1.2", "GB/s"))
    }

    @Test func valueNeverUsesMoreThanThreeDigits() {
        let samples: [UInt64] = [
            0, 9, 10, 99, 100, 999, 1_000, 1_500, 9_949, 9_950,
            15_000, 999_000, 999_500, 1_000_000, 12_500_000,
            999_900_000, 1_000_000_000, 12_500_000_000,
        ]
        for bytes in samples {
            for unit in DisplayUnit.allCases {
                let digits = SpeedFormat.components(bytesPerSecond: bytes, unit: unit).value.filter(\.isNumber).count
                #expect(digits <= 3)
            }
        }
    }
}
