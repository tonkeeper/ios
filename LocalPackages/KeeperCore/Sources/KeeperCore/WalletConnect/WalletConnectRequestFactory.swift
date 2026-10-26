import Foundation

@frozen public enum WalletConnectRequestFactory {
    public static func makeRequest(
        id: String,
        topic: String,
        method: WalletConnectMethod,
        chain: WalletConnectChain,
        payload: WalletConnectRequestPayload,
        dapp: WalletConnectDapp,
        source: DappConnectionSource?,
        walletId: String?
    ) throws(WalletConnectRequestParsingError) -> WalletConnectSessionRequest {
        guard method.isSupported(chain: chain) else {
            throw .unsupportedMethod(method.rawValue)
        }
        if case let .signMessage(message) = payload, message.kind == .typedDataV4 {
            try WalletConnectEthSignTypedDataV4Parser().validateDomainChain(of: message.message, against: chain)
        }
        return WalletConnectSessionRequest(
            id: id,
            topic: topic,
            chain: chain,
            method: method,
            dapp: dapp,
            payload: payload,
            source: source,
            walletId: walletId
        )
    }
}
