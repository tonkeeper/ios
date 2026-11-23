import Foundation
import LedgerKit
import TKLocalize

extension LedgerSteps where Value == Data {
    /// Signs a Solana transaction's message in the Solana app.
    static func solanaTransaction(_ message: Data, account: Int) -> LedgerSteps<Data> {
        LedgerSteps(
            stages: [.init(app: .solana, prompt: TKLocales.LedgerConfirm.Steps.Confirm.description)],
            run: { session in
                try await session.run(on: .solana) { link in
                    do {
                        return try await link.signSolanaMessage(message, path: SolanaApp.path(account: account))
                    } catch let error as LedgerStatusError where SolanaApp.requiresBlindSigning(error) {
                        throw LedgerStepsFailure(message: TKLocales.LedgerSteps.appSetting("Blind signing", LedgerApp.solana.name))
                    }
                }
            }
        )
    }
}
