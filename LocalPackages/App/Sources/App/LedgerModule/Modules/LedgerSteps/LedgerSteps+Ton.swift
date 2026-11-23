import Foundation
import KeeperCore
import LedgerKit
import TKLocalize
import TonSwift
import TonTransport

extension LedgerSteps where Value == [Data] {
    /// Signs TON transactions of one message each in the TON app, one confirmation each, once the app shows the
    /// Ledger holds the wallet of `publicKey`. Returns the signature of each transaction's signing message.
    static func tonTransactions(_ transactions: [LedgerTonTransaction], publicKey: TonSwift.PublicKey, account: Int) -> LedgerSteps<[Data]> {
        let prompt = transactions.count == 1
            ? TKLocales.LedgerConfirm.Steps.Confirm.description
            : TKLocales.LedgerSteps.confirmTransactions(transactions.count)
        return LedgerSteps(
            stages: [.init(app: .ton, prompt: prompt)],
            run: { session in
                try await session.run(on: .ton) { link in
                    let ton = TonTransport(link: link)
                    var signatures = [Data]()
                    for transaction in transactions {
                        try await signatures.append(ton.signTransaction(path: AccountPath(index: account), publicKey: publicKey, transaction: transaction))
                    }
                    return signatures
                }
            }
        )
    }
}
