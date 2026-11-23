import Foundation
import KeeperCore
import LedgerKit
import TKLocalize

extension LedgerSteps where Value == [Data] {
    /// Signs a spend from the account's one address in the Bitcoin app, once the app shows the Ledger holds the
    /// account. Returns a DER signature for each input in order.
    static func bitcoinTransaction(_ request: BitcoinDeviceSignRequest, account: Int) -> LedgerSteps<[Data]> {
        LedgerSteps(
            stages: [.init(app: .bitcoin, prompt: TKLocales.LedgerConfirm.Steps.Confirm.description)],
            run: { session in
                try await session.run(on: .bitcoin) { link in
                    let accountPath = BitcoinApp.accountPath(account: account)
                    guard try await link.bitcoinExtendedPublicKey(path: accountPath) == request.accountXpub else {
                        throw LedgerStepsFailure(message: TKLocales.LedgerSteps.otherWallet)
                    }
                    let fingerprint = try await link.bitcoinMasterFingerprint()
                    let keyPath = accountPath + [0, 0]
                    let transaction = BitcoinApp.Transaction(
                        version: request.version,
                        lockTime: request.lockTime,
                        inputs: request.inputs.map {
                            BitcoinApp.Input(
                                previousTxid: $0.previousTxid,
                                previousIndex: $0.previousIndex,
                                amount: $0.amount,
                                script: $0.script,
                                publicKey: request.publicKey,
                                path: keyPath,
                                previousTransaction: $0.previousTransaction,
                                sequence: $0.sequence
                            )
                        },
                        outputs: request.outputs.map {
                            BitcoinApp.Output(amount: $0.amount, script: $0.script, change: $0.isChange ? (request.publicKey, keyPath) : nil)
                        }
                    )
                    let policy = BitcoinApp.Policy(fingerprint: fingerprint, account: account, accountXpub: request.accountXpub)
                    let signatures = try await link.signBitcoinTransaction(transaction, policy: policy, fingerprint: fingerprint)
                    return try request.inputs.indices.map { index in
                        guard let signed = signatures.first(where: { $0.inputIndex == index && $0.publicKey == request.publicKey }),
                              signed.signature.last == 0x01
                        else {
                            throw LedgerTransportError.invalidResponse
                        }
                        return Data(signed.signature.dropLast())
                    }
                }
            }
        )
    }
}
