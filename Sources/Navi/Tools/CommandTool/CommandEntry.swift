import Foundation

/// A single bookmarked command and its search keywords.
struct CommandEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var command: String
    var keywords: [String]

    init(id: UUID = UUID(), command: String, keywords: [String]) {
        self.id = id
        self.command = command
        self.keywords = keywords
    }
}
