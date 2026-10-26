import Foundation

struct WalletConnectSolanaAccountsParser: WalletConnectMethodPayloadParser {
    func parse(
        chain _: WalletConnectChain,
        paramsJSON _: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        .solanaAccounts
    }
}
