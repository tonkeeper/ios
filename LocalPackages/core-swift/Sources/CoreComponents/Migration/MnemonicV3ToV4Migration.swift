import Foundation

public struct MnemonicV3ToV4Migration {
  private let v3Vault: MnemonicsV3Vault
  private let v4Vault: MnemonicsV4Vault
  
  public init(v3Vault: MnemonicsV3Vault, v4Vault: MnemonicsV4Vault) {
    self.v3Vault = v3Vault
    self.v4Vault = v4Vault
  }
  
  public func migrate(password: String) async throws {
    let v3Mnemonics = await v3Vault.getAllMnemonics(password: password)
    guard !v3Mnemonics.isEmpty else { return }
    
    try await v4Vault.importMnemonics(v3Mnemonics, password: password)
  }
  
  public func isNeedToMigrate() -> Bool {
    v3Vault.hasMnemonics()
  }
}
