import Foundation
import CoreComponents
import TonSwift

public final class MigrationV3 {
  
  private let mnemonicMigration: MnemonicV3ToV4Migration
  private var settingsRepository: SettingsRepository
  
  public init(mnemonicMigration: MnemonicV3ToV4Migration,
              settingsRepository: SettingsRepository) {
    self.mnemonicMigration = mnemonicMigration
    self.settingsRepository = settingsRepository
  }

  public func checkIfNeedToMigrate() -> Bool {
    !settingsRepository.didMigrateV3 && mnemonicMigration.isNeedToMigrate()
  }
  
  public func migrate(passcodeProvider: () async -> String) async throws {
    try await mnemonicMigration.migrate(password: passcodeProvider())
    settingsRepository.didMigrateV3 = true
  }
}
