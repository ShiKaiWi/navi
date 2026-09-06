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
        .navigationTitle("NetSpeed")
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
            Text(SpeedFormat.display(bytesPerSecond: speed, unit: unit))
        }
    }
}
