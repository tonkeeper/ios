import Foundation
import KeeperCore
import LedgerKit
import TKLogging

struct LedgerNetworkRead<Value: Sendable>: Sendable {
    let value: Value
    let missingApps: [LedgerApp]
}

enum LedgerAppRead<Value: Sendable>: Sendable {
    case value(Value)
    case skipped
    case missing
    case declined

    var value: Value? {
        guard case let .value(value) = self else {
            return nil
        }
        return value
    }

    var isMissing: Bool {
        if case .missing = self {
            return true
        }
        return false
    }
}

extension LedgerSession {
    func ethereumKeys(accounts: [Int]) async throws -> [LedgerAppKeys.Key] {
        try await keys(on: .ethereum, accounts: accounts) { link, account in
            let reply = try await link.ethereumAccount(path: EthereumApp.path(account: account))
            return LedgerAppKeys.Key(publicKey: reply.publicKey, address: reply.address)
        }
    }

    func tronKeys(accounts: [Int]) async throws -> [LedgerAppKeys.Key] {
        try await keys(on: .tron, accounts: accounts) { link, account in
            let reply = try await link.tronAccount(path: TronApp.path(account: account))
            return LedgerAppKeys.Key(publicKey: reply.publicKey, address: reply.address)
        }
    }

    func solanaKeys(accounts: [Int]) async throws -> [Data] {
        try await keys(on: .solana, accounts: accounts) { link, account in
            try await link.solanaPublicKey(path: SolanaApp.path(account: account))
        }
    }

    /// The extended key of each account, as `LedgerAppKeys.bitcoin` takes it.
    func bitcoinKeys(accounts: [Int]) async throws -> [String] {
        try await keys(on: .bitcoin, accounts: accounts) { link, account in
            try await link.bitcoinExtendedPublicKey(path: BitcoinApp.accountPath(account: account))
        }
    }

    /// The app's keys, or why it did not hand them out, so the other apps' keys can still count.
    func optionalKeys<T: Sendable>(
        on app: LedgerApp,
        choice: LedgerAppChoice,
        _ read: @escaping @Sendable (LedgerSession) async throws -> T
    ) async throws -> LedgerAppRead<T> {
        guard try await choice.isConfirmed(app) else {
            Log.i("Ledger app skipped by the user: \(app.name)")
            return .skipped
        }
        do {
            return try await withThrowingTaskGroup(of: OptionalStage<T>.self) { group in
                group.addTask { try await .keys(read(self)) }
                group.addTask {
                    try await choice.stopped(app)
                    return .stopped
                }
                let first = try await group.next()
                group.cancelAll()
                // A stop that lands as the app answers still wins: the steps already show the app skipped.
                guard let keys = first?.keys, (try? await group.next()) == nil else {
                    Log.i("Ledger app stopped by the user: \(app.name)")
                    return .skipped
                }
                return .value(keys)
            }
        } catch let error as LedgerStatusError where error.isAppMissing {
            Log.i("Ledger app skipped", error: error)
            return .missing
        } catch let error as LedgerStatusError where error.isRefused {
            Log.i("Ledger app skipped", error: error)
            return .declined
        }
    }

    private enum OptionalStage<T: Sendable>: Sendable {
        case keys(T)
        case stopped

        var keys: T? {
            guard case let .keys(keys) = self else {
                return nil
            }
            return keys
        }
    }

    private func keys<Key: Sendable>(
        on app: LedgerApp,
        accounts: [Int],
        read: @escaping @Sendable (LedgerLink, Int) async throws -> Key
    ) async throws -> [Key] {
        try await run(on: app, retryBody: true) { link in
            var keys: [Key] = []
            for account in accounts {
                try await keys.append(read(link, account))
            }
            return keys
        }
    }
}
