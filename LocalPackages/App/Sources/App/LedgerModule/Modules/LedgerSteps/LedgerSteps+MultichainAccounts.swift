import Foundation
import KeeperCore
import LedgerKit
import TKLocalize
import TonTransport

extension LedgerSteps where Value == LedgerNetworkRead<[AccountPath: LedgerMultichainAccount]> {
    /// Each account signs its wallet key proof in the TON app and hands over its keys in the apps behind `chains`.
    static func multichainAccounts(
        _ accounts: [LedgerAccount],
        chains: [MultichainChain]
    ) -> LedgerSteps<LedgerNetworkRead<[AccountPath: LedgerMultichainAccount]>> {
        let indices = accounts.map(\.path.index)
        let apps = LedgerDiscovery.chainApps(for: chains)
        return LedgerSteps(
            stages: [.init(app: .ton, prompt: TKLocales.LedgerConfirm.Steps.ConfirmProof.description)]
                + apps.map { .init(app: $0, prompt: nil, adds: $0.name, startsAutomatically: true) },
            run: { session, choice in
                let proofs = try await session.walletKeyProofs(accounts)
                let evmRead: LedgerAppRead<[LedgerAppKeys.Key]> = if apps.contains(.ethereum) {
                    try await session.optionalKeys(on: .ethereum, choice: choice) { try await $0.ethereumKeys(accounts: indices) }
                } else {
                    .skipped
                }
                let tronRead: LedgerAppRead<[LedgerAppKeys.Key]> = if apps.contains(.tron) {
                    try await session.optionalKeys(on: .tron, choice: choice) { try await $0.tronKeys(accounts: indices) }
                } else {
                    .skipped
                }
                let solanaRead: LedgerAppRead<[Data]> = if apps.contains(.solana) {
                    try await session.optionalKeys(on: .solana, choice: choice) { try await $0.solanaKeys(accounts: indices) }
                } else {
                    .skipped
                }
                let bitcoinRead: LedgerAppRead<[String]> = if apps.contains(.bitcoin) {
                    try await session.optionalKeys(on: .bitcoin, choice: choice) { try await $0.bitcoinKeys(accounts: indices) }
                } else {
                    .skipped
                }
                return LedgerNetworkRead(
                    value: Dictionary(uniqueKeysWithValues: accounts.enumerated().map { index, account in
                        let keys = LedgerAppKeys(
                            evm: evmRead.value?[index],
                            tron: tronRead.value?[index],
                            solana: solanaRead.value?[index],
                            bitcoin: bitcoinRead.value?[index]
                        )
                        return (account.path, LedgerMultichainAccount(proofSignature: proofs[index], keys: keys))
                    }),
                    missingApps: [
                        (LedgerApp.ethereum, evmRead.isMissing),
                        (.tron, tronRead.isMissing),
                        (.solana, solanaRead.isMissing),
                        (.bitcoin, bitcoinRead.isMissing),
                    ].compactMap { $0.1 ? $0.0 : nil }
                )
            }
        )
    }
}

extension LedgerSteps where Value == [Data] {
    /// Each account signs its wallet key proof in the TON app, in the order given.
    static func walletKeyProofs(_ accounts: [LedgerAccount]) -> LedgerSteps<[Data]> {
        LedgerSteps(
            stages: [.init(app: .ton, prompt: TKLocales.LedgerConfirm.Steps.ConfirmProof.description)],
            run: { session in
                try await session.walletKeyProofs(accounts)
            }
        )
    }
}

private extension LedgerSession {
    /// The TON app refuses an account whose key is not the one given, so another seed or passphrase is caught before
    /// the proof.
    func walletKeyProofs(_ accounts: [LedgerAccount]) async throws -> [Data] {
        try await run(on: .ton) { link in
            let ton = TonTransport(link: link)
            var proofs: [Data] = []
            for account in accounts {
                let proof = try await ton.signAddressProof(
                    path: account.path,
                    publicKey: account.publicKey,
                    domain: LedgerWalletKey.proofDomain,
                    timestamp: LedgerWalletKey.proofTimestamp,
                    payload: LedgerWalletKey.proofPayload
                )
                proofs.append(proof)
            }
            return proofs
        }
    }
}
