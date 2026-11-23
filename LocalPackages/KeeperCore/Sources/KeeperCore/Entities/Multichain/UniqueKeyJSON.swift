import Foundation

/// Foundation keeps the first of repeated keys and ChainKit the last, so a document read here and
/// signed by ChainKit has to name every key once at every level, or the two read different documents.
enum UniqueKeyJSON {
    private static let maxDepth = 64

    /// One JSON value and nothing after it, in which no object repeats a key once escapes are read.
    static func isWellFormed(_ text: String) -> Bool {
        var scanner = Scanner(bytes: Array(text.utf8))
        return scanner.document()
    }

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0

        mutating func document() -> Bool {
            skipWhitespace()
            guard value(depth: 0) else { return false }
            skipWhitespace()
            return index == bytes.count
        }

        private mutating func value(depth: Int) -> Bool {
            guard depth <= UniqueKeyJSON.maxDepth, let byte = peek() else { return false }
            switch byte {
            case UInt8(ascii: "{"):
                return object(depth: depth + 1)
            case UInt8(ascii: "["):
                return array(depth: depth + 1)
            case UInt8(ascii: "\""):
                return string() != nil
            case UInt8(ascii: "t"):
                return literal("true")
            case UInt8(ascii: "f"):
                return literal("false")
            case UInt8(ascii: "n"):
                return literal("null")
            default:
                return number()
            }
        }

        private mutating func object(depth: Int) -> Bool {
            index += 1
            skipWhitespace()
            if consume("}") { return true }
            var keys = Set<String>()
            repeat {
                skipWhitespace()
                guard peek() == UInt8(ascii: "\""), let key = string(), keys.insert(key).inserted else { return false }
                skipWhitespace()
                guard consume(":") else { return false }
                skipWhitespace()
                guard value(depth: depth) else { return false }
                skipWhitespace()
            } while consume(",")
            return consume("}")
        }

        private mutating func array(depth: Int) -> Bool {
            index += 1
            skipWhitespace()
            if consume("]") { return true }
            repeat {
                skipWhitespace()
                guard value(depth: depth) else { return false }
                skipWhitespace()
            } while consume(",")
            return consume("]")
        }

        private mutating func string() -> String? {
            index += 1
            var decoded = [UInt8]()
            while let byte = peek() {
                index += 1
                switch byte {
                case UInt8(ascii: "\""):
                    return String(bytes: decoded, encoding: .utf8)
                case UInt8(ascii: "\\"):
                    guard let escaped = escape() else { return nil }
                    decoded.append(contentsOf: escaped)
                case 0 ..< 0x20:
                    return nil
                default:
                    decoded.append(byte)
                }
            }
            return nil
        }

        private mutating func escape() -> [UInt8]? {
            guard let byte = peek() else { return nil }
            index += 1
            switch byte {
            case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"):
                return [byte]
            case UInt8(ascii: "b"):
                return [0x08]
            case UInt8(ascii: "f"):
                return [0x0C]
            case UInt8(ascii: "n"):
                return [0x0A]
            case UInt8(ascii: "r"):
                return [0x0D]
            case UInt8(ascii: "t"):
                return [0x09]
            case UInt8(ascii: "u"):
                guard var codePoint = hexQuad() else { return nil }
                if (0xD800 ... 0xDBFF).contains(codePoint) {
                    guard consume("\\"), consume("u"), let low = hexQuad(), (0xDC00 ... 0xDFFF).contains(low) else { return nil }
                    codePoint = 0x10000 + ((codePoint - 0xD800) << 10) + (low - 0xDC00)
                }
                guard let scalar = Unicode.Scalar(codePoint) else { return nil }
                return Array(String(Character(scalar)).utf8)
            default:
                return nil
            }
        }

        private mutating func hexQuad() -> UInt32? {
            guard index + 4 <= bytes.count,
                  let text = String(bytes: bytes[index ..< index + 4], encoding: .utf8),
                  text.allSatisfy(\.isHexDigit),
                  let value = UInt32(text, radix: 16)
            else { return nil }
            index += 4
            return value
        }

        private mutating func number() -> Bool {
            _ = consume("-")
            if consume("0") {
                if let byte = peek(), isDigit(byte) { return false }
            } else if !digits() {
                return false
            }
            if consume("."), !digits() { return false }
            guard let byte = peek(), byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E") else { return true }
            index += 1
            if let sign = peek(), sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") {
                index += 1
            }
            return digits()
        }

        private mutating func digits() -> Bool {
            let start = index
            while let byte = peek(), isDigit(byte) {
                index += 1
            }
            return index > start
        }

        private mutating func literal(_ word: String) -> Bool {
            let expected = Array(word.utf8)
            guard index + expected.count <= bytes.count, Array(bytes[index ..< index + expected.count]) == expected else { return false }
            index += expected.count
            return true
        }

        private mutating func consume(_ character: Unicode.Scalar) -> Bool {
            guard peek() == UInt8(ascii: character) else { return false }
            index += 1
            return true
        }

        private mutating func skipWhitespace() {
            while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                index += 1
            }
        }

        private func peek() -> UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        private func isDigit(_ byte: UInt8) -> Bool {
            (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(byte)
        }
    }
}
