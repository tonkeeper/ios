@preconcurrency import BigInt
import Foundation

struct WalletConnectSwitchEthereumChainParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .walletSwitchEthereumChain
        let params = try utilities.parseFirst(
            SwitchEthereumChainParameter.self,
            paramsJSON: paramsJSON,
            method: method
        )
        let targetChain = try targetChain(from: params.chainId, method: method)
        return .switchEthereumChain(targetChain)
    }

    private func targetChain(
        from chainId: String,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> WalletConnectChain {
        let normalized = chainId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalized.hasPrefix("0x"), normalized.count > 2 else {
            throw .invalidParams(method: method, reason: "chainId must be a 0x-prefixed hex string")
        }
        guard let decimalValue = BigUInt(String(normalized.dropFirst(2)), radix: 16) else {
            throw .invalidParams(method: method, reason: "chainId is not a valid hex string")
        }
        guard let chain = WalletConnectChain(caip2: "eip155:\(decimalValue)") else {
            throw .unsupportedChain("eip155:\(decimalValue)")
        }
        return chain
    }
}

private struct SwitchEthereumChainParameter: Decodable {
    let chainId: String
}
