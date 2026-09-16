import Foundation

struct WalletConnectTronSignMessageParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .tronSignMessage
        struct Params: Decodable {
            var address: String?
            var message: String
        }
        let params = try utilities.decode(
            Params.self,
            from: paramsJSON,
            method: method
        ) { error in
            "failed to decode tron message: \(error)"
        }

        return .signMessage(
            WalletConnectSignMessage(
                address: params.address,
                message: params.message,
                kind: .tron
            )
        )
    }
}
