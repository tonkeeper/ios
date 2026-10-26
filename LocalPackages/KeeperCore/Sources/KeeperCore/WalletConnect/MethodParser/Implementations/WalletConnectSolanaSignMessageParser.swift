import Foundation
import TKCryptoKit

struct WalletConnectSolanaSignMessageParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .solanaSignMessage
        struct Params: Decodable {
            var pubkey: String?
            var message: String
        }
        let params = try utilities.decode(
            Params.self,
            from: paramsJSON,
            method: method
        ) { error in
            "failed to decode solana message: \(error)"
        }
        guard !params.message.decodeBase58.isEmpty else {
            throw .invalidParams(method: method, reason: "solana message is not base58")
        }

        return .signMessage(
            WalletConnectSignMessage(
                address: params.pubkey,
                message: params.message,
                kind: .solana
            )
        )
    }
}
