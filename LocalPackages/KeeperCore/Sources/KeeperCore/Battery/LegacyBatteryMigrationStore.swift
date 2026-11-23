import Foundation
import TKKeychain
import TKLogging

struct LegacyBatteryMigrationStore {
    struct State: Codable, Sendable {
        var pending = [String: LegacyBatteryMigration]()
        var completed = Set<String>()
    }

    let keychainVault: TKKeychainVault
    let namespace: String

    func load() throws -> State {
        do {
            return try keychainVault.get(query: query)
        } catch TKKeychainError.noItem {
            return State()
        } catch let TKKeychainVaultError.decodingError(error) {
            Log.migration.e("legacy battery migration queue could not decode", error: error)
            return State()
        }
    }

    func save(_ state: State) throws {
        try keychainVault.set(state, query: query)
    }

    private var query: TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(service: "LegacyBatteryMigration.v1", account: namespace),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }
}
