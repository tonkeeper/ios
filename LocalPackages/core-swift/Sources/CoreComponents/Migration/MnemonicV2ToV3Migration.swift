import Foundation

public struct MnemonicV2ToV3Migration {
  private let v2Vault: MnemonicsV2Vault
  private let v3Vault: MnemonicsV3Vault
  
  public init(v2Vault: MnemonicsV2Vault, v3Vault: MnemonicsV3Vault) {
    self.v2Vault = v2Vault
    self.v3Vault = v3Vault
  }
  
  public func migrate(password: String) async throws {
    let v2Mnemonics = try v2Vault.getAllMnemonics(password: password)
    guard !v2Mnemonics.isEmpty else { return }
    
    try await v3Vault.importMnemonics(v2Mnemonics, password: password)
    
    try? v2Mnemonics.keys.forEach {
      try v2Vault.deleteMnemonic(key: $0, password: password)
    }
  }
}
