import Foundation

/// An order-preserving representation of a parsed JSON document.
///
/// `JSONSerialization` decodes objects into `NSDictionary`, which loses the
/// original key order — undesirable for a formatter where users expect their
/// keys to stay put. This enum is produced by a small recursive-descent parser
/// (`JSONParser`) that walks the raw text and keeps object keys in insertion order.
indirect enum JSONValue: Equatable {
    case object([Member])
    case array([JSONValue])
    case string(String)
    /// Stored as the original text so large integers / precision aren't mangled.
    case number(String)
    case bool(Bool)
    case null

    struct Member: Equatable {
        let key: String
        let value: JSONValue
    }
}

extension JSONValue {
    /// A short summary used in collapsed tree rows, e.g. `{3}` or `[5]`.
    var summary: String {
        switch self {
        case .object(let members): "{\(members.count)}"
        case .array(let items): "[\(items.count)]"
        default: ""
        }
    }

    var isContainer: Bool {
        switch self {
        case .object, .array: true
        default: false
        }
    }

    /// Re-serializes the value as pretty-printed JSON with the given indent unit.
    func prettyPrinted(indent: String = "  ", level: Int = 0) -> String {
        let pad = String(repeating: indent, count: level)
        let childPad = String(repeating: indent, count: level + 1)

        switch self {
        case .object(let members):
            guard !members.isEmpty else { return "{}" }
            let body = members.map { member in
                "\(childPad)\(JSONValue.encodeString(member.key)): \(member.value.prettyPrinted(indent: indent, level: level + 1))"
            }.joined(separator: ",\n")
            return "{\n\(body)\n\(pad)}"
        case .array(let items):
            guard !items.isEmpty else { return "[]" }
            let body = items.map { item in
                "\(childPad)\(item.prettyPrinted(indent: indent, level: level + 1))"
            }.joined(separator: ",\n")
            return "[\n\(body)\n\(pad)]"
        case .string(let s):
            return JSONValue.encodeString(s)
        case .number(let n):
            return n
        case .bool(let b):
            return b ? "true" : "false"
        case .null:
            return "null"
        }
    }

    /// Escapes a Swift string into a JSON string literal (including quotes).
    static func encodeString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case let c where c.value < 0x20:
                out += String(format: "\\u%04x", c.value)
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }
}

// MARK: - Parser

/// A minimal recursive-descent JSON parser that preserves object key order.
struct JSONParser {
    enum ParseError: LocalizedError {
        case unexpectedEnd
        case unexpected(Character, at: Int)
        case invalidNumber(at: Int)
        case invalidEscape(at: Int)
        case invalidLiteral(at: Int)
        case trailingData(at: Int)

        var errorDescription: String? {
            switch self {
            case .unexpectedEnd:
                "Unexpected end of input"
            case .unexpected(let c, let i):
                "Unexpected character '\(c)' at position \(i)"
            case .invalidNumber(let i):
                "Invalid number at position \(i)"
            case .invalidEscape(let i):
                "Invalid escape sequence at position \(i)"
            case .invalidLiteral(let i):
                "Invalid literal at position \(i)"
            case .trailingData(let i):
                "Unexpected trailing data at position \(i)"
            }
        }
    }

    private let scalars: [Character]
    private var index = 0

    private init(_ text: String) {
        self.scalars = Array(text)
    }

    /// Parses `text` into a `JSONValue`, throwing `ParseError` on malformed input.
    static func parse(_ text: String) throws -> JSONValue {
        var parser = JSONParser(text)
        parser.skipWhitespace()
        let value = try parser.parseValue()
        parser.skipWhitespace()
        if parser.index != parser.scalars.count {
            throw ParseError.trailingData(at: parser.index)
        }
        return value
    }

    private var current: Character? {
        index < scalars.count ? scalars[index] : nil
    }

    private mutating func skipWhitespace() {
        while let c = current, c == " " || c == "\n" || c == "\r" || c == "\t" {
            index += 1
        }
    }

    private mutating func parseValue() throws -> JSONValue {
        guard let c = current else { throw ParseError.unexpectedEnd }
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .string(try parseString())
        case "t", "f": return try parseBool()
        case "n": return try parseNull()
        case "-", "0"..."9": return .number(try parseNumber())
        default: throw ParseError.unexpected(c, at: index)
        }
    }

    private mutating func parseObject() throws -> JSONValue {
        index += 1 // consume {
        var members: [JSONValue.Member] = []
        skipWhitespace()
        if current == "}" { index += 1; return .object(members) }

        while true {
            skipWhitespace()
            guard current == "\"" else {
                if let c = current { throw ParseError.unexpected(c, at: index) }
                throw ParseError.unexpectedEnd
            }
            let key = try parseString()
            skipWhitespace()
            guard current == ":" else {
                if let c = current { throw ParseError.unexpected(c, at: index) }
                throw ParseError.unexpectedEnd
            }
            index += 1 // consume :
            skipWhitespace()
            let value = try parseValue()
            members.append(.init(key: key, value: value))
            skipWhitespace()
            switch current {
            case ",": index += 1
            case "}": index += 1; return .object(members)
            case .some(let c): throw ParseError.unexpected(c, at: index)
            case .none: throw ParseError.unexpectedEnd
            }
        }
    }

    private mutating func parseArray() throws -> JSONValue {
        index += 1 // consume [
        var items: [JSONValue] = []
        skipWhitespace()
        if current == "]" { index += 1; return .array(items) }

        while true {
            skipWhitespace()
            items.append(try parseValue())
            skipWhitespace()
            switch current {
            case ",": index += 1
            case "]": index += 1; return .array(items)
            case .some(let c): throw ParseError.unexpected(c, at: index)
            case .none: throw ParseError.unexpectedEnd
            }
        }
    }

    private mutating func parseString() throws -> String {
        index += 1 // consume opening quote
        var result = ""
        while let c = current {
            switch c {
            case "\"":
                index += 1
                return result
            case "\\":
                index += 1
                guard let esc = current else { throw ParseError.unexpectedEnd }
                switch esc {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "u":
                    let scalar = try parseUnicodeEscape()
                    result.unicodeScalars.append(scalar)
                    continue // parseUnicodeEscape advanced the index past the digits
                default:
                    throw ParseError.invalidEscape(at: index)
                }
                index += 1
            default:
                result.append(c)
                index += 1
            }
        }
        throw ParseError.unexpectedEnd
    }

    /// Parses `\uXXXX` (and surrogate pairs). Assumes `index` points at the `u`.
    private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
        let high = try readHex4()
        if (0xD800...0xDBFF).contains(high) {
            // Expect a low surrogate to follow.
            if current == "\\" && index + 1 < scalars.count && scalars[index + 1] == "u" {
                index += 2 // consume \u
                let low = try readHex4()
                let value = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
                guard let scalar = Unicode.Scalar(value) else {
                    throw ParseError.invalidEscape(at: index)
                }
                return scalar
            }
            throw ParseError.invalidEscape(at: index)
        }
        guard let scalar = Unicode.Scalar(high) else {
            throw ParseError.invalidEscape(at: index)
        }
        return scalar
    }

    /// Reads 4 hex digits following a `u`. Assumes `index` points at the `u`.
    private mutating func readHex4() throws -> Int {
        index += 1 // consume u
        guard index + 4 <= scalars.count else { throw ParseError.unexpectedEnd }
        let hex = String(scalars[index..<index + 4])
        guard let value = Int(hex, radix: 16) else {
            throw ParseError.invalidEscape(at: index)
        }
        index += 4
        return value
    }

    private mutating func parseNumber() throws -> String {
        let start = index
        if current == "-" { index += 1 }
        while let c = current, c.isNumber { index += 1 }
        if current == "." {
            index += 1
            while let c = current, c.isNumber { index += 1 }
        }
        if current == "e" || current == "E" {
            index += 1
            if current == "+" || current == "-" { index += 1 }
            while let c = current, c.isNumber { index += 1 }
        }
        let text = String(scalars[start..<index])
        // Validate the captured token is a real number.
        guard Double(text) != nil else { throw ParseError.invalidNumber(at: start) }
        return text
    }

    private mutating func parseBool() throws -> JSONValue {
        if matches("true") { return .bool(true) }
        if matches("false") { return .bool(false) }
        throw ParseError.invalidLiteral(at: index)
    }

    private mutating func parseNull() throws -> JSONValue {
        if matches("null") { return .null }
        throw ParseError.invalidLiteral(at: index)
    }

    private mutating func matches(_ literal: String) -> Bool {
        let chars = Array(literal)
        guard index + chars.count <= scalars.count else { return false }
        for (offset, ch) in chars.enumerated() where scalars[index + offset] != ch {
            return false
        }
        index += chars.count
        return true
    }
}
