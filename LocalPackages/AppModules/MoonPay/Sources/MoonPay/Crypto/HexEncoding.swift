import Foundation

enum HexEncoding {
    /// Strict: an optional `0x` prefix, an even number of hex digits, nothing else.
    static func decode(_ string: String) -> Data? {
        var hex = Substring(string)
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = hex.dropFirst(2)
            guard !hex.isEmpty else { return nil }
        }
        guard hex.count.isMultiple(of: 2), hex.allSatisfy(\.isHexDigit) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    static func encode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
