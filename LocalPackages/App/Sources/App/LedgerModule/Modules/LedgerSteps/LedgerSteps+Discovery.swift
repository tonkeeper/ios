import Foundation
import KeeperCore
import LedgerKit
import TonTransport

/// What a Ledger hands out for some of its accounts before any is chosen: each account's TON key and its keys in the
/// chain apps that answered.
struct LedgerDiscovery: Sendable {
    /// The chain apps pairing reads besides TON, in the order it opens them.
    static let chainApps: [LedgerApp] = [.ethereum, .tron, .solana, .bitcoin]

    static func chainApps(for chains: [MultichainChain]) -> [LedgerApp] {
        chainApps.filter { app in
            chains.contains { $0.ledgerApp == app }
        }
    }

    /// Each account's key in the TON app, by account index.
    let tonKeys: [Int: Data]
    let keys: [Int: LedgerAppKeys]
    /// The chain apps that handed out keys; further accounts are read in these only.
    let apps: [LedgerApp]
}

extension LedgerSteps where Value == LedgerDiscovery {
    /// Reads the accounts at `indices` in each of `apps` the Ledger has, then in the TON app, which it must have. The
    /// TON app is left open for the wallet key proofs that follow the choice. With `choosesApps`, the user may skip
    /// any selected app.
    static func discovery(_ indices: [Int], apps: [LedgerApp], choosesApps: Bool) -> LedgerSteps<LedgerDiscovery> {
        LedgerSteps(
            stages: apps.map { .init(app: $0, prompt: nil, adds: choosesApps ? $0.name : nil, startsAutomatically: choosesApps) }
                + [.init(app: .ton, prompt: nil)],
            run: { session, choice in
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
                let evm = evmRead.value
                let tron = tronRead.value
                let solana = solanaRead.value
                let bitcoin = bitcoinRead.value
                let tonKeys = try await session.run(on: .ton, retryBody: true) { link in
                    let ton = TonTransport(link: link)
                    var keys: [Data] = []
                    for index in indices {
                        try await keys.append(ton.getAccount(path: AccountPath(index: index)).publicKey.data)
                    }
                    return keys
                }
                let answered = [(LedgerApp.ethereum, evm != nil), (.tron, tron != nil), (.solana, solana != nil), (.bitcoin, bitcoin != nil)]
                    .filter(\.1)
                    .map(\.0)
                return LedgerDiscovery(
                    tonKeys: Dictionary(uniqueKeysWithValues: zip(indices, tonKeys)),
                    keys: Dictionary(uniqueKeysWithValues: indices.enumerated().map { position, index in
                        (index, LedgerAppKeys(evm: evm?[position], tron: tron?[position], solana: solana?[position], bitcoin: bitcoin?[position]))
                    }),
                    apps: apps.filter { app in answered.contains(app) }
                )
            }
        )
    }
}
