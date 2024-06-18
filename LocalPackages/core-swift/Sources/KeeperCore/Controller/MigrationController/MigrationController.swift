import Foundation

public final class MigrationController {
  private let sharedCacheURL: URL
  private let keychainAccessGroupIdentifier: String
  private let rootAssembly: KeeperCore.RootAssembly
  
  private let migrationV1: MigrationV1
  private var migrationV2: MigrationV2
  
  init(sharedCacheURL: URL,
       keychainAccessGroupIdentifier: String,
       rootAssembly: KeeperCore.RootAssembly) {
    self.sharedCacheURL = sharedCacheURL
    self.keychainAccessGroupIdentifier = keychainAccessGroupIdentifier
    self.rootAssembly = rootAssembly
    self.migrationV1 = MigrationV1(
      keeperInfoDirectory: sharedCacheURL,
      sharedKeychainGroup: keychainAccessGroupIdentifier
    )
    self.migrationV2 = MigrationV2(
      keeperInfoDirectory: sharedCacheURL,
      walletsStoreUpdate: rootAssembly.walletsUpdateAssembly.walletsStoreUpdate,
      mnemonicsRepositoryV1: rootAssembly.repositoriesAssembly.mnemonicRepository(),
      mnemonicsRepository: rootAssembly.repositoriesAssembly.mnemonicsRepository(),
      passcodeRepository: rootAssembly.repositoriesAssembly.passcodeRepository(),
      settingsRepository: rootAssembly.repositoriesAssembly.settingsRepository()
    )
  }
  
  public func checkIfNeedToMigrate() -> Bool {
    migrationV1.checkIfNeedToMigrate() || migrationV2.checkIfNeedToMigrate()
  }
  
  public func migrate(passcodeHandler: (_ validation: @escaping (String) async -> Bool) async -> String) async throws {
    if migrationV1.checkIfNeedToMigrate() {
      migrationV1.migrateKeeperInfo()
    }
    if migrationV2.checkIfNeedToMigrate() {
      try await migrationV2.migrate {
        let validation: (String) async -> Bool = { input in
          do {
            let storedPasscode = try self.rootAssembly.repositoriesAssembly.passcodeRepository().getPasscode().value
            return input == storedPasscode
          } catch {
            return false
          }
        }
        let passcode = await passcodeHandler(validation)
        return passcode
      }
    }
  }
}
