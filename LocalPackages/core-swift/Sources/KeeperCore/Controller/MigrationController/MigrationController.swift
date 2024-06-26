import Foundation

public final class MigrationController {
  private let sharedCacheURL: URL
  private let keychainAccessGroupIdentifier: String
  private let rootAssembly: KeeperCore.RootAssembly
  private let isTonkeeperX: Bool
  
  private let migrationV1: MigrationV1
  private var migrationV2: MigrationV2
  private var rnMigration: RNMigration
  
  init(sharedCacheURL: URL,
       keychainAccessGroupIdentifier: String,
       rootAssembly: KeeperCore.RootAssembly,
       isTonkeeperX: Bool) {
    self.sharedCacheURL = sharedCacheURL
    self.keychainAccessGroupIdentifier = keychainAccessGroupIdentifier
    self.rootAssembly = rootAssembly
    self.isTonkeeperX = isTonkeeperX
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
    self.rnMigration = RNMigration(
      walletsStoreUpdate: rootAssembly.walletsUpdateAssembly.walletsStoreUpdate,
      settingsRepository: rootAssembly.repositoriesAssembly.settingsRepository(),
      mnemonicsRepository: rootAssembly.repositoriesAssembly.mnemonicsRepository(),
      keychainVault: rootAssembly.coreAssembly.keychainVault
    )
  }
  
  public func checkIfNeedToMigrate() -> Bool {
    if isTonkeeperX {
      checkIfNeedToMigrateTonkeeperX()
    } else {
      checkIfNeedToMigrateTonkeeperRN()
    }
  }
  
  public func migrate(passcodeHandler: (_ validation: @escaping (String) async -> Bool) async -> String) async throws {
    if isTonkeeperX {
      return try await migrateTonkeeperX(passcodeHandler: passcodeHandler)
    } else {
      return try await migrateTonkeeperRN(passcodeHandler: passcodeHandler)
    }
  }
  
  private func checkIfNeedToMigrateTonkeeperX() -> Bool {
    migrationV1.checkIfNeedToMigrate() || migrationV2.checkIfNeedToMigrate()
  }
  
  private func migrateTonkeeperX(passcodeHandler: (_ validation: @escaping (String) async -> Bool) async -> String) async throws {
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
  
  private func checkIfNeedToMigrateTonkeeperRN() -> Bool {
    rnMigration.checkIfNeedToMigrate()
  }
  
  private func migrateTonkeeperRN(passcodeHandler: (_ validation: @escaping (String) async -> Bool) async -> String) async throws {
    guard rnMigration.checkIfNeedToMigrate() else { return }
    try await rnMigration.migrate { passcodeValidation in
      let passcode = await passcodeHandler(passcodeValidation)
      return passcode
    }
  }
}