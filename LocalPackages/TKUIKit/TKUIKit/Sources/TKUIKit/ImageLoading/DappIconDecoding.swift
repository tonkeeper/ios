import Foundation

public enum DataURIDecoder {
    public static func decode(_ url: URL) -> Data? {
        guard url.scheme?.lowercased() == "data" else { return nil }
        return decode(string: url.absoluteString)
    }

    public static func decode(string: String) -> Data? {
        guard string.hasPrefix("data:"),
              let commaIndex = string.firstIndex(of: ",")
        else {
            return nil
        }

        let metaStart = string.index(string.startIndex, offsetBy: 5)
        let meta = string[metaStart ..< commaIndex]
        let payload = String(string[string.index(after: commaIndex)...])

        if meta.lowercased().contains(";base64") {
            return Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
        }
        return fullyPercentDecoded(payload).data(using: .utf8)
    }

    // `URL(string:)` double-encodes raw `{ } '` in some dapp `data:` icons, so a single
    // `removingPercentEncoding` leaves the payload still encoded. Decode until it stabilizes.
    private static func fullyPercentDecoded(_ string: String) -> String {
        var current = string
        for _ in 0 ..< 5 {
            guard let decoded = current.removingPercentEncoding, decoded != current else {
                break
            }
            current = decoded
        }
        return current
    }
}

public enum SVGDetection {
    private static let marker = Array("<svg".utf8)

    public static func looksLikeSVG(_ data: Data) -> Bool {
        let window = [UInt8](data.prefix(1024)).map { byte -> UInt8 in
            (byte >= 65 && byte <= 90) ? byte + 32 : byte
        }
        guard window.count >= marker.count else { return false }
        for start in 0 ... (window.count - marker.count) where Array(window[start ..< start + marker.count]) == marker {
            return true
        }
        return false
    }
}
