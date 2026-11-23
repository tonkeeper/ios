import Foundation
import LedgerKit
import TKLocalize

extension LedgerSteps where Value == Data {
    /// Signs a `personal_sign` message in the Ethereum app.
    static func ethereumMessage(_ message: Data, account: Int) -> LedgerSteps<Data> {
        LedgerSteps(
            stages: [.init(app: .ethereum, prompt: TKLocales.LedgerSteps.signMessage)],
            run: { session in
                try await session.run(on: .ethereum) { link in
                    try await link.signEthereumPersonalMessage(message, path: EthereumApp.path(account: account))
                }
            }
        )
    }

    /// Signs EIP-712 data by its two hashes, which the Ethereum app shows only with blind signing on.
    static func ethereumTypedData(domainSeparator: Data, messageHash: Data, account: Int) -> LedgerSteps<Data> {
        LedgerSteps(
            stages: [.init(app: .ethereum, prompt: TKLocales.LedgerSteps.signMessage)],
            run: { session in
                try await session.run(on: .ethereum) { link in
                    guard try await link.ethereumBlindSigningEnabled() else {
                        throw LedgerStepsFailure(message: TKLocales.LedgerSteps.blindSigning)
                    }
                    return try await link.signEthereumTypedDataHashes(
                        domainSeparator: domainSeparator,
                        messageHash: messageHash,
                        path: EthereumApp.path(account: account)
                    )
                }
            }
        )
    }

    /// Signs a `tron_signMessage` message in the Tron app.
    static func tronMessage(_ message: Data, account: Int) -> LedgerSteps<Data> {
        LedgerSteps(
            stages: [.init(app: .tron, prompt: TKLocales.LedgerSteps.signMessage)],
            run: { session in
                try await session.run(on: .tron) { link in
                    try await link.signTronPersonalMessage(message, path: TronApp.path(account: account))
                }
            }
        )
    }
}
