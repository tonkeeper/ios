import Foundation
import TKKeychain
import TKLogging

/// Keychain home of the device certificate private key. Device-only and never migrated:
/// a restore onto another device must register as a new device.
final class DeviceCertificateStore {
    private let keychainVault: TKKeychainVault

    init(keychainVault: TKKeychainVault) {
        self.keychainVault = keychainVault
    }

    func load() -> Data? {
        do {
            // Explicit type: an inferred `Data?` would pick the `Codable` overload and decode.
            let privateKey: Data = try keychainVault.get(query: query)
            return privateKey
        } catch TKKeychainVaultError.unexpectedData, TKKeychainError.noItem {
            return nil
        } catch {
            Log.w("🪵 DeviceAuth: load certificate failed", error: error)
            return nil
        }
    }

    func save(_ privateKey: Data) throws {
        try keychainVault.set(privateKey, query: query)
    }

    private var query: TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(service: "MultichainDeviceCertificate", account: "device"),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }
}
