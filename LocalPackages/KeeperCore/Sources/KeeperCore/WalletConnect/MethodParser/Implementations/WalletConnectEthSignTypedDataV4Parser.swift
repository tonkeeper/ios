@preconcurrency import BigInt
import Foundation

struct WalletConnectEthSignTypedDataV4Parser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let params = try utilities.parseStringList(paramsJSON: paramsJSON, method: method)
        guard params.count >= 2 else {
            throw .invalidParams(method: method, reason: "eth_signTypedData_v4 requires address and typed data")
        }

        return try .signMessage(
            WalletConnectSignMessage(
                address: params[0],
                message: canonicalTypedData(params[1], chain: chain),
                kind: .typedDataV4
            )
        )
    }

    /// The typed data re-serialized from the object that is validated here and shown to the user.
    /// Foundation keeps the first of repeated keys and wallet-core the last, so signing the dApp's
    /// own string would sign values the wallet never checked or displayed.
    func canonicalTypedData(
        _ typedData: String,
        chain: WalletConnectChain
    ) throws(WalletConnectRequestParsingError) -> String {
        let data = try utilities.data(
            from: typedData,
            method: method,
            utf8FailureReason: "typed data is not utf8"
        )
        guard let document = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              JSONSerialization.isValidJSONObject(document),
              let canonical = try? JSONSerialization.data(
                  withJSONObject: document,
                  options: [.sortedKeys, .withoutEscapingSlashes]
              )
        else {
            throw .invalidParams(method: method, reason: "typed data is not a JSON object")
        }

        try validateDomainChain(of: canonical, against: chain)
        return String(decoding: canonical, as: UTF8.self)
    }
}

private extension WalletConnectEthSignTypedDataV4Parser {
    var method: WalletConnectMethod {
        .ethSignTypedDataV4
    }

    func validateDomainChain(
        of typedData: Data,
        against chain: WalletConnectChain
    ) throws(WalletConnectRequestParsingError) {
        let header: TypedDataHeader
        do {
            header = try JSONDecoder().decode(TypedDataHeader.self, from: typedData)
        } catch {
            throw .invalidParams(method: method, reason: "typed data domain is malformed: \(error.logDescription)")
        }

        guard let domainChainId = header.domain?.chainId?.value else {
            if header.declaresDomainChainId {
                throw .invalidParams(method: method, reason: "typed data domain declares chainId without a value")
            }
            return
        }
        if let expectedChainId = chain.eip155ChainId, domainChainId != BigUInt(expectedChainId) {
            throw .chainMismatch(expected: chain, actual: domainChainId.description)
        }
    }

    struct TypedDataHeader: Decodable {
        struct Field: Decodable {
            var name: String
        }

        struct Types: Decodable {
            var domain: [Field]?

            private enum CodingKeys: String, CodingKey {
                case domain = "EIP712Domain"
            }
        }

        struct Domain: Decodable {
            var chainId: WalletConnectUInt256Value?
        }

        var types: Types?
        var domain: Domain?

        var declaresDomainChainId: Bool {
            types?.domain?.contains { $0.name == "chainId" } == true
        }
    }
}
