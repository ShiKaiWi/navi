import Testing
@testable import Navi

struct CommandSearchTests {
    private let entries = [
        CommandEntry(command: "git log --oneline", keywords: ["git", "日志"]),
        CommandEntry(command: "docker compose up -d", keywords: ["docker", "容器"]),
        CommandEntry(command: "curl -X POST http://localhost:8080", keywords: ["http", "请求"]),
    ]

    @Test func emptyQueryReturnsAllEntries() {
        #expect(CommandSearch.search("", in: entries) == entries)
    }

    @Test func exactCommandMatchRanksFirst() {
        #expect(CommandSearch.search("docker", in: entries).first?.command == "docker compose up -d")
    }

    @Test func keywordMatch() {
        #expect(CommandSearch.search("日志", in: entries).first?.command == "git log --oneline")
    }

    @Test func fuzzyMatchToleratesTypo() {
        #expect(CommandSearch.search("doker", in: entries).first?.command == "docker compose up -d")
    }

    @Test func multipleTokensBoostMatches() {
        #expect(CommandSearch.search("docker compose", in: entries).first?.command == "docker compose up -d")
    }

    @Test func noMatchReturnsEmpty() {
        #expect(CommandSearch.search("zzzzzz", in: entries).isEmpty)
    }
}
