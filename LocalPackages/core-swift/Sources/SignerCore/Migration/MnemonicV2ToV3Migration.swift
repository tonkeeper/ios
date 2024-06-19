import CoreComponents

public struct MnemonicV2ToV3Migration {
  
  private let migration: CoreComponents.MnemonicV2ToV3Migration
  
  init(migration: CoreComponents.MnemonicV2ToV3Migration) {
    self.migration = migration
  }
  
  public func migrateIfNeeded(password: String) async throws {
    try await migration.migrate(password: password)
  }
}
