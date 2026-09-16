import BigInt
import Foundation

/// ERC-681 transaction request URLs, carried by the ERC-831 `ethereum:` / `eth:` scheme with an
/// optional `pay-` prefix. Only plain value transfers and ERC-20 `transfer` calls map onto the
/// send flow — every other function, and any target that is not a hex address, is rejected.
struct EthereumTransferLinkParser {
    private enum Scheme {
        static let all = ["ethereum:", "eth:"]
        static let payPrefix = "pay-"
    }

    private enum Parameter {
        static let value = "value"
        static let address = "address"
        static let uint256 = "uint256"
    }

    private enum Function {
        static let transfer = "transfer"
    }

    init() {}

    func parse(string: String) -> Deeplink.EvmTransferData? {
        guard let payload = payload(from: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let (head, query) = split(payload, separator: "?")
        let (targetAndChain, function) = split(head, separator: "/")
        let (rawTarget, rawChainId) = split(targetAndChain, separator: "@")

        guard let target = hexAddress(rawTarget),
              let chain = chain(from: rawChainId)
        else {
            return nil
        }

        let parameters = parameters(from: query)

        switch function?.lowercased() {
        case nil, "":
            guard let amount = amount(parameters[Parameter.value]) else { return nil }
            return Deeplink.EvmTransferData(
                recipient: target,
                asset: .native,
                chain: chain,
                amount: amount
            )
        case Function.transfer:
            guard let recipient = hexAddress(parameters[Parameter.address]),
                  let amount = amount(parameters[Parameter.uint256])
            else {
                return nil
            }
            return Deeplink.EvmTransferData(
                recipient: recipient,
                asset: .erc20(contract: target),
                chain: chain,
                amount: amount
            )
        default:
            return nil
        }
    }
}

private extension EthereumTransferLinkParser {
    func payload(from string: String) -> String? {
        let lowercased = string.lowercased()
        guard let scheme = Scheme.all.first(where: { lowercased.hasPrefix($0) }) else {
            return nil
        }
        let body = String(string.dropFirst(scheme.count))

        if body.lowercased().hasPrefix(Scheme.payPrefix) {
            return String(body.dropFirst(Scheme.payPrefix.count))
        }
        // ERC-831 allows arbitrary use-case prefixes; only `pay-` maps onto a transfer, and a
        // bare payload is a transfer only when it starts with an address rather than an ENS name.
        return body.lowercased().hasPrefix("0x") ? body : nil
    }

    func split(_ string: String, separator: Character) -> (String, String?) {
        guard let index = string.firstIndex(of: separator) else {
            return (string, nil)
        }
        return (String(string[..<index]), String(string[string.index(after: index)...]))
    }

    func hexAddress(_ string: String?) -> String? {
        guard let string,
              string.count == 42,
              string.lowercased().hasPrefix("0x"),
              string.dropFirst(2).allSatisfy(\.isHexDigit)
        else {
            return nil
        }
        return string
    }

    /// Nested optional: the outer level separates "no chain id" from "a chain id we cannot honour",
    /// the inner one carries the chain the link pinned.
    func chain(from rawChainId: String?) -> MultichainChain?? {
        guard let rawChainId else { return .some(nil) }
        guard rawChainId.allSatisfy({ $0.isASCII && $0.isNumber }),
              let chainId = Int(rawChainId),
              let chain = MultichainChain(eip155ChainId: chainId)
        else {
            return nil
        }
        return .some(chain)
    }

    func parameters(from query: String?) -> [String: String] {
        guard let query else { return [:] }
        return query.split(separator: "&").reduce(into: [String: String]()) { result, pair in
            let (name, value) = split(String(pair), separator: "=")
            guard let value, !name.isEmpty, result[name] == nil else { return }
            result[name] = value.removingPercentEncoding ?? value
        }
    }

    /// Nested optional, as in `chain(from:)`: a malformed amount invalidates the whole link
    /// instead of silently opening the send form with an empty field.
    func amount(_ raw: String?) -> BigUInt?? {
        guard let raw else { return .some(nil) }
        guard let amount = ERC681Amount.atomicUnits(from: raw) else { return nil }
        return .some(amount)
    }
}

enum ERC681Amount {
    /// The largest power of ten that still fits a `uint256`, so an absurd exponent cannot turn
    /// into an arbitrarily large allocation.
    private static let maxExponent = 78

    /// ERC-681 numbers are decimal with an optional power-of-ten exponent (`2.014e18`). The
    /// exponent has to cover the fractional digits — otherwise the value is not a whole number
    /// of atomic units and the link cannot be honoured exactly.
    static func atomicUnits(from string: String) -> BigUInt? {
        var mantissa = string
        var exponent = 0

        if let index = mantissa.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            let rawExponent = String(mantissa[mantissa.index(after: index)...])
            mantissa = String(mantissa[..<index])
            if !rawExponent.isEmpty {
                guard rawExponent.allSatisfy({ $0.isASCII && $0.isNumber }),
                      let value = Int(rawExponent)
                else {
                    return nil
                }
                exponent = value
            }
        }

        if mantissa.hasPrefix("+") {
            mantissa.removeFirst()
        }

        var fractionDigits = 0
        if let index = mantissa.firstIndex(of: ".") {
            let fraction = String(mantissa[mantissa.index(after: index)...])
            fractionDigits = fraction.count
            mantissa = String(mantissa[..<index]) + fraction
        }

        let scale = exponent - fractionDigits
        guard !mantissa.isEmpty,
              mantissa.allSatisfy({ $0.isASCII && $0.isNumber }),
              scale >= 0,
              scale <= maxExponent,
              let digits = BigUInt(mantissa)
        else {
            return nil
        }

        return digits * BigUInt(10).power(scale)
    }
}
