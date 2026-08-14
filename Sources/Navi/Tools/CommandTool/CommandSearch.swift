import Foundation

/// Pure, side-effect-free search and scoring over saved commands.
///
/// Matching is "combined": exact substring/token matches rank first, and when
/// a query token has no substring hit, a Levenshtein fuzzy match fills in so
/// small typos (`gti` → `git`) still surface results. Scores only order
/// results, so they are deliberately coarse rather than a calibrated metric.
enum CommandSearch {
    /// Returns entries matching `query`, ordered by descending similarity.
    /// An empty query returns the entries unchanged (newest first).
    static func search(_ query: String, in entries: [CommandEntry]) -> [CommandEntry] {
        let tokens = tokens(from: query)
        guard !tokens.isEmpty else { return entries }
        return entries
            .map { (entry: $0, score: score(entry: $0, tokens: tokens)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.entry)
    }

    /// The total similarity score for one entry against already-normalized tokens.
    static func score(entry: CommandEntry, tokens: [String]) -> Double {
        let command = entry.command.lowercased()
        let keywords = entry.keywords.map { $0.lowercased() }
        var total = 0.0

        for token in tokens {
            var best = exactScore(token, in: command)
            for keyword in keywords {
                best = max(best, exactScore(token, in: keyword) * keywordWeight)
            }
            if best == 0 {
                var fuzzy = fuzzyScore(token, in: command)
                for keyword in keywords {
                    fuzzy = max(fuzzy, fuzzyScore(token, in: keyword) * keywordWeight)
                }
                best = fuzzy * fuzzyWeight
            }
            total += best
        }
        return total
    }

    // MARK: - Internals

    /// Keywords match slightly less strongly than the command text itself.
    private static let keywordWeight = 0.85
    /// Fuzzy matches always rank below any exact substring match.
    private static let fuzzyWeight = 0.6
    /// Below this similarity a fuzzy hit is noise and is discarded.
    private static let fuzzyThreshold = 0.5

    private static func tokens(from query: String) -> [String] {
        query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    /// 1.0 + a position bonus for substring matches; 0 when absent.
    /// The bonus decays from 0.5 at the start of the text toward 0 at the end.
    private static func exactScore(_ token: String, in text: String) -> Double {
        guard let range = text.range(of: token) else { return 0 }
        let index = text.distance(from: text.startIndex, to: range.lowerBound)
        let positionBonus = 0.5 * (1.0 - Double(index) / Double(max(text.count, 1)))
        return 1.0 + positionBonus
    }

    /// 0...1 similarity via Levenshtein edit distance, or 0 below the threshold.
    private static func fuzzyScore(_ token: String, in text: String) -> Double {
        guard !text.isEmpty || !token.isEmpty else { return 0 }
        let distance = levenshtein(token, text)
        let similarity = 1.0 - Double(distance) / Double(max(token.count, text.count))
        return similarity >= fuzzyThreshold ? similarity : 0
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(
                    min(current[j - 1] + 1, previous[j] + 1),
                    substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
