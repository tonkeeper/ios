import BigInt
import Foundation

enum MultichainActivityAmount {
    /// History's amounts are in base units, signed by their direction.
    static func unsigned(_ value: String) -> BigUInt? {
        var normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2212}", with: "-")

        guard !normalized.isEmpty else {
            return nil
        }

        if normalized.first == "+" || normalized.first == "-" {
            normalized.removeFirst()
        }

        guard normalized.allSatisfy({ "0123456789".contains($0) }) else {
            return nil
        }

        return BigUInt(normalized)
    }
}
