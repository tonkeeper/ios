import Foundation
import TKKeychain

/// Shared by the device-auth and multichain-binding suites: keychain-backed stores are the
/// persistence boundary both of them exercise.
final class InMemoryKeychainVault: TKKeychainVault, @unchecked Sendable {
    var readError: Error?
    /// When set, every write fails with it — the keychain refusing a write is a real state for
    /// `.afterFirstUnlockThisDeviceOnly` items.
    var writeError: Error?
    /// Lets a suite assert that a store served a value from memory instead of the keychain.
    private(set) var readCount = 0
    var itemCount: Int {
        items.count
    }

    private var items = [String: Data]()

    func exists(query: TKKeychainQuery) throws -> Bool {
        items[key(for: query)] != nil
    }

    func biometricAccessState(query _: TKKeychainQuery) -> TKKeychainBiometryAccess {
        .missing
    }

    func get(query: TKKeychainQuery) throws -> Data {
        readCount += 1
        if let readError {
            throw readError
        }
        guard let data = items[key(for: query)] else {
            throw TKKeychainError.noItem
        }
        return data
    }

    func get(query: TKKeychainQuery) throws -> String {
        guard let string = try String(data: get(query: query), encoding: .utf8) else {
            throw TKKeychainVaultError.unexpectedData
        }
        return string
    }

    func get<T: Codable>(query: TKKeychainQuery) throws -> T {
        try JSONDecoder().decode(T.self, from: get(query: query))
    }

    func set(_ value: Data, query: TKKeychainQuery) throws {
        if let writeError {
            throw writeError
        }
        items[key(for: query)] = value
    }

    func set(_ value: String, query: TKKeychainQuery) throws {
        guard let data = value.data(using: .utf8) else {
            throw TKKeychainVaultError.unexpectedData
        }
        try set(data, query: query)
    }

    func set<T: Codable>(_ value: T, query: TKKeychainQuery) throws {
        try set(JSONEncoder().encode(value), query: query)
    }

    func delete(_ query: TKKeychainQuery) throws {
        if let writeError {
            throw writeError
        }
        // An omitted account matches every item under the service, which is how a store wipes
        // accounts it no longer knows the names of.
        if case let .genericPassword(service, account) = query.item, account == nil {
            let matches = items.keys.filter { $0.hasPrefix("\(service):") }
            guard !matches.isEmpty else {
                throw TKKeychainError.noItem
            }
            matches.forEach { items.removeValue(forKey: $0) }
            return
        }
        guard items.removeValue(forKey: key(for: query)) != nil else {
            throw TKKeychainError.noItem
        }
    }

    private func key(for query: TKKeychainQuery) -> String {
        switch query.item {
        case let .genericPassword(service, account):
            return "\(service):\(account ?? "")"
        }
    }
}
