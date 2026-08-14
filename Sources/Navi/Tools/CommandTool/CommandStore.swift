import Foundation
import Observation

/// Owns the list of bookmarked commands and persists it as JSON.
///
/// The store is an `@Observable` reference type so SwiftUI re-renders whenever
/// `entries` changes. Mutations go through `add`/`update`/`delete`, each of
/// which writes the full list back to disk atomically.
@Observable
final class CommandStore {
    var entries: [CommandEntry] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = appSupport.appendingPathComponent("Navi", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("commands.json")
        load()
    }

    func add(command: String, keywords: [String]) {
        // Insert at the front so an empty query lists newest commands first.
        entries.insert(CommandEntry(command: command, keywords: keywords), at: 0)
        save()
    }

    func update(_ entry: CommandEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        save()
    }

    func delete(_ entry: CommandEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            entries = try JSONDecoder().decode([CommandEntry].self, from: data)
        } catch {
            NSLog("CommandStore: failed to decode %@: %@", fileURL.path, String(describing: error))
            entries = []
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("CommandStore: failed to write %@: %@", fileURL.path, String(describing: error))
        }
    }
}
