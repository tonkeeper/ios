import Foundation
import TKKeychain
import TKLogging

/// Persists the half of the token pair that survives a relaunch. The access token is
/// deliberately absent: `securitySchemes.deviceJWT` requires it to stay in memory.
///
/// The record is mirrored in memory because `device_id` is read per analytics event, which the
/// Keychain is far too expensive for. One instance owns the mirror, so every reader has to share
/// it — see `Assembly.deviceTokenStore`.
final class DeviceTokenStore: @unchecked Sendable {
    struct Record: Codable, Hashable, Sendable {
        let deviceId: String
        let refreshToken: String
    }

    private let keychainVault: TKKeychainVault
    private let lock = NSLock()
    private var cachedRecord: Record?
    /// Only a conclusive answer primes the mirror: a Keychain that could not be read at all
    /// (locked device) has to be retried rather than remembered as "no record".
    private var isCachePrimed = false
    private var didLogLoadFailure = false

    init(keychainVault: TKKeychainVault) {
        self.keychainVault = keychainVault
    }

    func load() -> Record? {
        lock.lock()
        defer { lock.unlock() }
        if isCachePrimed {
            return cachedRecord
        }
        do {
            let record: Record = try keychainVault.get(query: query)
            prime(record)
            return record
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            prime(nil)
            return nil
        } catch {
            // Logged once: a per-event caller would otherwise repeat this for the whole time the
            // Keychain stays unreadable.
            if !didLogLoadFailure {
                didLogLoadFailure = true
                Log.w("🪵 DeviceAuth: load tokens failed", error: error)
            }
            return nil
        }
    }

    func save(_ record: Record) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try keychainVault.set(record, query: query)
            prime(record)
        } catch {
            Log.w("🪵 DeviceAuth: save tokens failed", error: error)
        }
    }

    func delete() {
        lock.lock()
        defer { lock.unlock() }
        try? keychainVault.delete(query)
        // The record belongs to a certificate that is already gone, so it must not come back
        // from the mirror even if the Keychain refused the delete.
        prime(nil)
    }

    private func prime(_ record: Record?) {
        cachedRecord = record
        isCachePrimed = true
        didLogLoadFailure = false
    }

    private var query: TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(service: "MultichainDeviceTokens", account: "device"),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }
}
