import ChainKit

extension OperationGate {
    typealias TonSigning = (TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions

    /// `sign`, with the TON request built from what it is handed reviewed beside it and only logged
    /// while the checks prove themselves on TON. The passcode or the Ledger does not wait for that
    /// review: chain-kit may look a jetton's wallet up on the network to read the request, and
    /// nothing cancels the lookup. The App builds the request it signs once more, so what is
    /// reviewed is a copy.
    func clearing(
        _ sign: @escaping TonSigning,
        account: @escaping (Wallet) throws -> ChainKit.Account,
        intent: OperationIntent,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> TonSigning {
        { transferData, wallet throws(TransactionConfirmationError) in
            Task {
                try await clear(.logOnly, consent: .refuse, file: file, function: function, line: line) {
                    let transfer = try await UnsignedTransferBuilder(transferData: transferData).createUnsignedWalletTransfer(wallet: wallet)
                    return try [.ton(
                        SignableOperation.TonRequest(signing: transfer),
                        of: wallet,
                        account: account(wallet),
                        intent: intent,
                        fidelity: .converted
                    )]
                }
            }
            return try await sign(transferData, wallet)
        }
    }
}
