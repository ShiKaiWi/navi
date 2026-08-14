import SwiftUI

struct TimestampView: View {
    @State private var input: String = ""
    @State private var selectedTimezone: TimeZone = .current
    @State private var currentTimestamp: TimeInterval = Date().timeIntervalSince1970
    @State private var timezoneSearch: String = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// All timezones, built once. Building a `TimeZone` for each of the ~440
    /// known identifiers is cheap, but it must not happen on every render.
    private static let availableTimezones: [TimeZone] =
        TimeZone.knownTimeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }

    private var filteredTimezones: [TimeZone] {
        let query = timezoneSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.availableTimezones }
        return Self.availableTimezones.filter { tz in
            tz.identifier.localizedCaseInsensitiveContains(query)
                || tz.cityName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            inputSection
            timezoneSection
            resultSection
            Divider()
            currentTimeSection
            Spacer()
        }
        .padding()
        .onReceive(timer) { _ in
            currentTimestamp = Date().timeIntervalSince1970
        }
        .navigationTitle("Timestamp")
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Input")
                .font(.headline)
            TextField("Enter timestamp or date string...", text: $input)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
        }
    }

    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Timezone")
                .font(.headline)

            // Search field + lazy list instead of a `Picker`. A `Picker` with
            // the ~440 `TimeZone.knownTimeZoneIdentifiers` builds every menu
            // item eagerly on the main thread, which stalls the switch for
            // ~150 ms. A lazily-rendered, filtered list stays responsive and
            // is far easier to scan than a 440-item dropdown.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter timezones…", text: $timezoneSearch)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTimezones, id: \.identifier) { tz in
                        timezoneRow(tz)
                    }
                }
                .padding(4)
            }
            .frame(height: 160)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func timezoneRow(_ timezone: TimeZone) -> some View {
        let isSelected = timezone == selectedTimezone
        return HStack(spacing: 8) {
            Text(timezone.identifier)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
        .onTapGesture {
            selectedTimezone = timezone
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Result")
                .font(.headline)

            if input.isEmpty {
                Text("Type a timestamp or date to convert")
                    .foregroundStyle(.secondary)
            } else {
                let result = convert(input: input, timezone: selectedTimezone)
                switch result {
                case .timestamp(let formatted):
                    resultRow(label: "Date:", value: formatted)
                case .date(let ms):
                    resultRow(label: "Timestamp (ms):", value: String(ms))
                case .error(let message):
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard")
        }
    }

    private var currentTimeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Time")
                .font(.headline)
            HStack {
                Text("Unix:")
                    .foregroundStyle(.secondary)
                Text(String(Int64(currentTimestamp)))
                    .font(.body.monospaced())
            }
            HStack {
                Text("ISO 8601:")
                    .foregroundStyle(.secondary)
                Text(formatISO8601(date: Date(timeIntervalSince1970: currentTimestamp), timezone: selectedTimezone))
                    .font(.body.monospaced())
            }
        }
    }

    // MARK: - Conversion Logic

    private enum ConversionResult {
        case timestamp(String)
        case date(Int64)
        case error(String)
    }

    private func convert(input: String, timezone: TimeZone) -> ConversionResult {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if let numeric = Double(trimmed), trimmed.allSatisfy({ $0.isNumber }) {
            let date: Date
            let digitCount = trimmed.count

            if digitCount == 13 {
                date = Date(timeIntervalSince1970: numeric / 1000)
            } else {
                date = Date(timeIntervalSince1970: numeric)
            }

            let now = Date()
            let hundredYears: TimeInterval = 100 * 365.25 * 24 * 3600
            if abs(date.timeIntervalSince(now)) > hundredYears && digitCount != 10 && digitCount != 13 {
                return .error("Timestamp appears out of reasonable range")
            }

            return .timestamp(formatISO8601(date: date, timezone: timezone))
        }

        if let date = parseDate(trimmed) {
            let ms = Int64(date.timeIntervalSince1970 * 1000)
            return .date(ms)
        }

        return .error("Unable to parse input")
    }

    private func parseDate(_ string: String) -> Date? {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: string) { return date }

        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: string) { return date }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
            "MMM dd, yyyy HH:mm:ss",
            "MMM dd, yyyy",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }

        return nil
    }

    private func formatISO8601(date: Date, timezone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}

private extension TimeZone {
    /// The trailing component of the identifier, e.g. "Shanghai" from
    /// "Asia/Shanghai". Used for friendlier search matching.
    var cityName: String {
        identifier.split(separator: "/").last.map(String.init) ?? identifier
    }
}
