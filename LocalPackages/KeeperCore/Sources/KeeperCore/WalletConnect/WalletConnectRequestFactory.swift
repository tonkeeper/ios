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
        var payload = payload
        if case var .signMessage(message) = payload, message.kind == .typedDataV4 {
            message.message = try WalletConnectEthSignTypedDataV4Parser().canonicalTypedData(message.message, chain: chain)
            payload = .signMessage(message)
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
