import Foundation

struct WalletConnectWalletGetCapabilitiesParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .walletGetCapabilities
        let params = try utilities.decode(
            WalletGetCapabilitiesParams.self,
            from: paramsJSON,
            method: method,
            failureReason: { "failed to decode params: \($0)" }
        )
        let chainIds = try requestedChainIds(
            params.chainIds,
            fallbackChain: chain,
            method: method
        )
        return .walletCapabilities(WalletConnectWalletCapabilitiesRequest(
            address: params.address,
            chainIds: chainIds
        ))
    }

    private func requestedChainIds(
        _ chainIds: [String]?,
        fallbackChain: WalletConnectChain,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> [String] {
        guard let chainIds, !chainIds.isEmpty else {
            return try [hexChainId(fallbackChain, method: method)]
        }

        for chainId in chainIds {
            guard chainId.walletConnectCanonicalHexChainId != nil else {
                throw .invalidParams(method: method, reason: "chainIds must be 0x-prefixed hex strings")
            }
        }
        return chainIds
    }

    private func hexChainId(
        _ chain: WalletConnectChain,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> String {
        guard let chainId = chain.eip155ChainId, chainId > 0 else {
            throw .invalidParams(method: method, reason: "fallback chain is not EIP-155")
        }
        return "0x\(String(Int(chainId), radix: 16))"
    }
}

private struct WalletGetCapabilitiesParams: Decodable {
    let address: String
    let chainIds: [String]?

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        address = try container.decode(String.self)

        if container.isAtEnd {
            chainIds = nil
        } else if try container.decodeNil() {
            chainIds = nil
        } else {
            chainIds = try container.decode([String].self)
        }

        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "wallet_getCapabilities expects [address, chainIds?]"
            )
        }
    }
}
