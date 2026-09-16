import Foundation

struct WalletConnectEthSignTransactionParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .ethSignTransaction
        let transaction = try utilities.parseFirst(
            WalletConnectEVMTransaction.self,
            paramsJSON: paramsJSON,
            method: method
        )

        return .evmTransaction(transaction, send: false)
    }
}
