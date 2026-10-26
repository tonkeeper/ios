import Foundation
import TKCryptoKit

/// Solana Pay transfer requests: `solana:<recipient>?amount=…&spl-token=…`. A `reference` or a
/// `memo` becomes part of the transaction the link asks for, and the send flow can carry neither,
/// so such a link is rejected instead of being paid without them. `label` and `message` are only
/// for display. A transaction request (`solana:https://…`) names an endpoint, not a recipient.
struct SolanaTransferLinkParser {
    private enum Parameter {
        static let amount = "amount"
        static let splToken = "spl-token"
        static let reference = "reference"
        static let memo = "memo"
    }

    private static let scheme = "solana:"
    private static let publicKeyLength = 32

    init() {}

    func parse(string: String) -> Deeplink.SolanaTransferData? {
        let link = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard link.lowercased().hasPrefix(Self.scheme) else {
            return nil
        }

        let (recipient, query) = split(String(link.dropFirst(Self.scheme.count)), separator: "?")
        let parameters = parameters(from: query)

        guard isPublicKey(recipient),
              parameters[Parameter.reference] == nil,
              parameters[Parameter.memo, default: ""].isEmpty,
              let asset = asset(mint: parameters[Parameter.splToken]),
              let amount = amount(parameters[Parameter.amount])
        else {
            return nil
        }

        return Deeplink.SolanaTransferData(
            recipient: recipient,
            asset: asset,
            amount: amount
        )
    }
}

private extension SolanaTransferLinkParser {
    func split(_ string: String, separator: Character) -> (String, String?) {
        guard let index = string.firstIndex(of: separator) else {
            return (string, nil)
        }
        return (String(string[..<index]), String(string[string.index(after: index)...]))
    }

    /// A parameter without a value still counts: a bare `reference` must reject the link too.
    func parameters(from query: String?) -> [String: String] {
        guard let query else { return [:] }
        return query.split(separator: "&").reduce(into: [String: String]()) { result, pair in
            let (name, value) = split(String(pair), separator: "=")
            guard !name.isEmpty, result[name] == nil else { return }
            let rawValue = value ?? ""
            result[name] = rawValue.removingPercentEncoding ?? rawValue
        }
    }

    func isPublicKey(_ string: String) -> Bool {
        string.decodeBase58.count == Self.publicKeyLength
    }

    func asset(mint: String?) -> Deeplink.SolanaTransferData.Asset? {
        guard let mint else { return .native }
        return isPublicKey(mint) ? .splToken(mint: mint) : nil
    }

    /// Nested optional: the outer level separates "no amount" from "an amount that is not a plain
    /// decimal number", which invalidates the whole link instead of opening an empty send form.
    func amount(_ raw: String?) -> Deeplink.DecimalAmount?? {
        guard let raw else { return .some(nil) }
        guard let amount = Deeplink.DecimalAmount(raw) else { return nil }
        return .some(amount)
    }
}
