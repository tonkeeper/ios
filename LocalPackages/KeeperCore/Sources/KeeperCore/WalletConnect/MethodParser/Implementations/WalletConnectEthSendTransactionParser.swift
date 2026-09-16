import Foundation

struct WalletConnectEthSendTransactionParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .ethSendTransaction
        let transaction = try utilities.parseFirst(
            WalletConnectEVMTransaction.self,
            paramsJSON: paramsJSON,
            method: method
        )

        return .evmTransaction(transaction, send: true)
    }
}
