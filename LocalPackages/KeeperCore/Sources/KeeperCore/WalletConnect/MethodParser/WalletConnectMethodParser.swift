import Foundation

enum WalletConnectRequestParsingError: Error, Equatable {
    case unsupportedMethod(String)
    case unsupportedChain(String)
    case invalidParams(method: WalletConnectMethod, reason: String)
    case chainMismatch(expected: WalletConnectChain, actual: String)
}

protocol WalletConnectMethodPayloadParser {
    func parse(
        chain: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload
}

struct WalletConnectMethodParser {
    private let parsers: [WalletConnectMethod: WalletConnectMethodPayloadParser]

    init() {
        parsers = [
            .personalSign: WalletConnectPersonalSignParser(),
            .ethSignTypedDataV4: WalletConnectEthSignTypedDataV4Parser(),
            .ethSignTransaction: WalletConnectEthSignTransactionParser(),
            .ethSendTransaction: WalletConnectEthSendTransactionParser(),
            .walletSwitchEthereumChain: WalletConnectSwitchEthereumChainParser(),
            .walletGetCapabilities: WalletConnectWalletGetCapabilitiesParser(),
            .tronSignMessage: WalletConnectTronSignMessageParser(),
            .tronSignTransaction: WalletConnectTronSignTransactionParser(),
            .tonSendMessage: WalletConnectTONSendMessageParser(),
            .tonSignData: WalletConnectTONSignDataParser(),
        ]
    }

    func parse(
        method methodName: String,
        chain caip2: String,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> (
        method: WalletConnectMethod,
        chain: WalletConnectChain,
        payload: WalletConnectRequestPayload
    ) {
        guard let method = WalletConnectMethod(rawValue: methodName) else {
            throw .unsupportedMethod(methodName)
        }
        guard let chain = WalletConnectChain(caip2: caip2) else {
            throw .unsupportedChain(caip2)
        }
        guard method.isSupported(chain: chain) else {
            throw .unsupportedMethod(methodName)
        }
        guard let parser = parsers[method] else {
            throw .unsupportedMethod(methodName)
        }

        let payload = try parser.parse(chain: chain, paramsJSON: paramsJSON)
        return (method, chain, payload)
    }
}
