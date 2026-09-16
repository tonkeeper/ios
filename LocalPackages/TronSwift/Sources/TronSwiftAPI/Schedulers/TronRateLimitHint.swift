import Foundation

/// TronGrid states its cooldown in the standard `Retry-After` header or, more often, in the 429
/// body: "the request rate of (getAccount) has been suspended for 1 s".
enum TronRateLimitHint {
    private static let maxScannedBytes = 8192

    private static let suspensionMarker = "suspended for"

    static func cooldown(response: HTTPURLResponse, data: Data) -> TimeInterval? {
        retryAfter(response: response) ?? suspension(data: data)
    }

    private static func retryAfter(response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces),
            let seconds = TimeInterval(value),
            seconds >= 0
        else {
            return nil
        }
        return seconds
    }

    private static func suspension(data: Data) -> TimeInterval? {
        guard !data.isEmpty,
              let body = String(data: data.prefix(maxScannedBytes), encoding: .utf8),
              let marker = body.range(of: suspensionMarker, options: [.caseInsensitive])
        else {
            return nil
        }

        let value = body[marker.upperBound...].drop(while: \.isWhitespace)
        let digits = value.prefix { $0.isNumber || $0 == "." }
        guard let seconds = TimeInterval(digits), seconds >= 0 else { return nil }

        // The message states seconds; anything else is a shape this parser does not know.
        let unit = value.dropFirst(digits.count).drop(while: \.isWhitespace)
        guard unit.first?.lowercased() == "s" else { return nil }

        return seconds
    }
}
