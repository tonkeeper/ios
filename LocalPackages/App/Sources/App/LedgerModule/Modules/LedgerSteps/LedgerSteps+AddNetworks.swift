import Foundation
import KeeperCore
import LedgerKit
import TKFeatureFlags
import TKLocalize
import TonSwift
import TonTransport

extension LedgerSteps where Value == LedgerNetworkRead<LedgerAppKeys> {
    /// Reads the keys of the apps behind `chains` once the TON app shows that the Ledger holds this wallet. The user
    /// may skip an app, or it may be left out when it is not on the Ledger or they would not open it.
    static func addNetworks(_ chains: [MultichainChain], tonPublicKey: TonSwift.PublicKey, account: Int) -> LedgerSteps<LedgerNetworkRead<LedgerAppKeys>> {
        let apps = LedgerDiscovery.chainApps(for: chains)
        return LedgerSteps(
            stages: [.init(app: .ton, prompt: nil)] + apps.map { .init(app: $0, prompt: nil, adds: $0.name, startsAutomatically: true) },
            run: { session, choice in
                let tonKey = try await session.run(on: .ton, retryBody: true) { link in
                    try await TonTransport(link: link).getAccount(path: AccountPath(index: account)).publicKey
                }
                guard tonKey.data == tonPublicKey.data else {
                    throw LedgerStepsFailure(message: TKLocales.LedgerSteps.otherWallet)
                }
                let evmRead: LedgerAppRead<[LedgerAppKeys.Key]> = if apps.contains(.ethereum) {
                    try await session.optionalKeys(on: .ethereum, choice: choice) { try await $0.ethereumKeys(accounts: [account]) }
                } else {
                    .skipped
                }
                let tronRead: LedgerAppRead<[LedgerAppKeys.Key]> = if apps.contains(.tron) {
                    try await session.optionalKeys(on: .tron, choice: choice) { try await $0.tronKeys(accounts: [account]) }
                } else {
                    .skipped
                }
                let solanaRead: LedgerAppRead<[Data]> = if apps.contains(.solana) {
                    try await session.optionalKeys(on: .solana, choice: choice) { try await $0.solanaKeys(accounts: [account]) }
                } else {
                    .skipped
                }
                let bitcoinRead: LedgerAppRead<[String]> = if apps.contains(.bitcoin) {
                    try await session.optionalKeys(on: .bitcoin, choice: choice) { try await $0.bitcoinKeys(accounts: [account]) }
                } else {
                    .skipped
                }
                return LedgerNetworkRead(
                    value: LedgerAppKeys(
                        evm: evmRead.value?.first,
                        tron: tronRead.value?.first,
                        solana: solanaRead.value?.first,
                        bitcoin: bitcoinRead.value?.first
                    ),
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

extension Wallet {
    /// The chains a Ledger wallet can add from its device apps once the multichain Ledger is rolled out: for a
    /// multichain one, those it has no address on; for a TON-only one in mainnet, all of them, once its upgrade to
    /// multichain is rolled out too.
    func addableLedgerChains(featureFlags: TKFeatureFlags) -> [MultichainChain] {
        guard kind == .ledger, featureFlags[.ledgerMultichain] else {
            return []
        }
        let chains = MultichainChain.displayOrder.filter(\.isEVM) + [.tron, .sol, .btc]
        guard let state = multichainWalletState else {
            return network == .mainnet && featureFlags[.ledgerMigration] ? chains : []
        }
        return chains.filter { chain in !state.addresses.contains { $0.chain == chain } }
    }
}

extension MultichainChain {
    /// The Ledger app that holds this chain's key.
    var ledgerApp: LedgerApp? {
        switch self {
        case .ton:
            .ton
        case .tron:
            .tron
        case .sol:
            .solana
        case .btc:
            .bitcoin
        case _ where isEVM:
            .ethereum
        default:
            nil
        }
    }
}
