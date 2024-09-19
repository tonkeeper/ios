import Foundation
import CoreComponents

public final class MigrationController {
  private let sharedCacheURL: URL
  private let keychainAccessGroupIdentifier: String
  private let rootAssembly: KeeperCore.RootAssembly
  
  private var rnMigration: RNMigration
  
  init(sharedCacheURL: URL,
       keychainAccessGroupIdentifier: String,
       rootAssembly: KeeperCore.RootAssembly) {
    self.sharedCacheURL = sharedCacheURL
    self.keychainAccessGroupIdentifier = keychainAccessGroupIdentifier
    self.rootAssembly = rootAssembly
    self.rnMigration = RNMigration(
      rnService: rootAssembly.rnAssembly.rnService,
      settingsRepository: rootAssembly.repositoriesAssembly.settingsRepository(),
      mnemonicsRepository: rootAssembly.repositoriesAssembly.mnemonicsRepository(),
      keychainVault: rootAssembly.coreAssembly.keychainVault
    )
  }
  
  public func checkIfNeedToMigrate() async -> Bool {
    await checkIfNeedToMigrateTonkeeperRN()
  }
  
  public func migrate(passcodeHandler: (_ validation: @escaping (String) async -> Bool) async -> String) async throws {
    return try await migrateTonkeeperRN(passcodeHandler: passcodeHandler)
  }
  
  private func checkIfNeedToMigrateTonkeeperRN() async -> Bool {
    await rnMigration.checkIfNeedToMigrate()
  }
  
  private func migrateTonkeeperRN(passcodeHandler: (_ validation: @escaping (String) async -> Bool) async -> String) async throws {
    guard await rnMigration.checkIfNeedToMigrate() else { return }
    try await rnMigration.migrate { passcodeValidation in
      let passcode = await passcodeHandler(passcodeValidation)
      return passcode
    }
  }
}
