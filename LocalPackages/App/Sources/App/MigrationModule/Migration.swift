import KeeperCore
import TKCore

struct Migration {
  private let coreAssembly: TKCore.CoreAssembly
  private let passcodeProvider: () async -> String?
  
  init(coreAssembly: TKCore.CoreAssembly, 
       passcodeProvider: @escaping () async -> String?) {
    self.coreAssembly = coreAssembly
    self.passcodeProvider = passcodeProvider
  }
  
  func migrateIfNeeded() async {
    migrateFromV1ToV1_1IfNeeded()
  }
  
  private func migrateFromV1ToV1_1IfNeeded() {
//    let migration = V1toV1_1Migration(
//      keeperInfoDirectory: coreAssembly.sharedCacheURL,
//      sharedKeychainGroup: coreAssembly.keychainAccessGroupIdentifier
//    )
//    migration.migrateKeeperInfoIfNeeded()
  }
  
  private func migrateV1_1IfNeeded() async {
//    let migration = V1_1Migration()
//    await migration.migrateIfNeeded(passcodeProvider: passcodeProvider)
  }
}
