import Foundation
import LedgerKit
import TKLocalize
import TonSwift
import TonTransport

extension LedgerSteps where Value == Void {
    /// Connects, opens the TON app and checks that the Ledger holds the wallet of `tonPublicKey`.
    static func checkConnection(tonPublicKey: TonSwift.PublicKey, account: Int) -> LedgerSteps<Void> {
        LedgerSteps(
            stages: [.init(app: .ton, prompt: nil)],
            run: { session in
                let key = try await session.run(on: .ton, retryBody: true) { link in
                    try await TonTransport(link: link).getAccount(path: AccountPath(index: account)).publicKey
                }
                guard key.data == tonPublicKey.data else {
                    throw LedgerStepsFailure(message: TKLocales.LedgerSteps.otherWallet)
                }
            }
        )
    }
}
