import Foundation
import TonSwift

public extension String {
    /// Addresses and hashes give way to `<hex>`, as the analytics schemas promise: long hex runs, and runs of
    /// 32 or more base58 or base64url characters with a digit in them, such as Tron and user-friendly addresses.
    var redactingAddresses: String {
        redactingTonFriendlyAddresses.replacingOccurrences(
            of: "(0x)?[0-9a-fA-F]{40,}|(?=[A-Za-z_-]*[0-9])[A-Za-z0-9_-]{32,}",
            with: "<hex>",
            options: .regularExpression
        )
    }

    private static let tonFriendlyAddressCandidate = try! NSRegularExpression(
        pattern: "[EUk0][Qf](?:[A-Za-z0-9_+/-]|%2[BbFf]){46}"
    )

    private var redactingTonFriendlyAddresses: String {
        let text = self as NSString
        var redacted = ""
        var copiedUntil = 0
        var searchFrom = 0
        while let match = Self.tonFriendlyAddressCandidate.firstMatch(
            in: text as String,
            range: NSRange(location: searchFrom, length: text.length - searchFrom)
        ) {
            let candidate = text.substring(with: match.range)
            guard (try? FriendlyAddress(string: candidate.removingPercentEncoding ?? candidate)) != nil else {
                searchFrom = match.range.location + 1
                continue
            }
            redacted += text.substring(with: NSRange(location: copiedUntil, length: match.range.location - copiedUntil))
            redacted += "<hex>"
            copiedUntil = NSMaxRange(match.range)
            searchFrom = copiedUntil
        }
        return copiedUntil == 0 ? self : redacted + text.substring(from: copiedUntil)
    }
}
