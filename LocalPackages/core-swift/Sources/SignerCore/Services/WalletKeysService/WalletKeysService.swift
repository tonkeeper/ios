import Foundation
import CoreComponents

public enum WalletKeysServiceError: Swift.Error {
  case incorrectWalletKey(WalletKey)
}

public enum WalletsKeysServiceDeleteWalletResult {
  case deletedKey
  case deletedAll
}

public protocol WalletKeysService {
  func getKeys() throws -> [WalletKey]
  func addKey(_ key: WalletKey) throws
  func updateKeyName(_ key: WalletKey, name: String) throws -> WalletKey
  func deleteKey(_ key: WalletKey) throws -> WalletsKeysServiceDeleteWalletResult
}

final class WalletKeysServiceImplementation: WalletKeysService {
  let signerInfoRepository: SignerInfoRepository
  
  init(signerInfoRepository: SignerInfoRepository) {
    self.signerInfoRepository = signerInfoRepository
  }
  
  func getKeys() throws -> [WalletKey] {
    try signerInfoRepository.getSignerInfo().walletKeys
  }
  
  func addKey(_ key: WalletKey) throws {
    let signerInfo: SignerInfo
    do {
      let currentSignerInfo = try signerInfoRepository.getSignerInfo()
      let updatedWalletKeys = currentSignerInfo.walletKeys.filter {
        $0.id != key.id
      } + CollectionOfOne(key)
      let updatedSignerInfo = currentSignerInfo.setWalletKeys(updatedWalletKeys)
      signerInfo = updatedSignerInfo
    } catch {
      signerInfo = createSignerInfo(walletKeys: [key])
    }
    
    try signerInfoRepository.saveSignerInfo(signerInfo)
  }
  
  func updateKeyName(_ key: WalletKey, name: String) throws -> WalletKey {
    let updatedKey = WalletKey(
      name: name,
      publicKey: key.publicKey
    )
    let currentSignerInfo = try signerInfoRepository.getSignerInfo()
    var keys = currentSignerInfo.walletKeys
    guard let index = currentSignerInfo.walletKeys.firstIndex(of: key) else { throw WalletKeysServiceError.incorrectWalletKey(key) }
    keys.remove(at: index)
    keys.insert(updatedKey, at: index)
    let updatedSignerInfo = currentSignerInfo.setWalletKeys(keys)
    try signerInfoRepository.saveSignerInfo(updatedSignerInfo)
    return updatedKey
  }
  
  func deleteKey(_ key: WalletKey) throws -> WalletsKeysServiceDeleteWalletResult {
    let currentSignerInfo = try signerInfoRepository.getSignerInfo()
    let keys = currentSignerInfo.walletKeys
      .filter { $0 != key }
    if keys.isEmpty {
      try signerInfoRepository.removeSignerInfo()
      return .deletedAll
    } else {
      let updatedSignerInfo = currentSignerInfo.setWalletKeys(keys)
      try signerInfoRepository.saveSignerInfo(updatedSignerInfo)
      return .deletedKey
    }
  }
}

private extension WalletKeysServiceImplementation {
  func createSignerInfo(walletKeys: [WalletKey]) -> SignerInfo {
    let signerInfo = SignerInfo(
      walletKeys: walletKeys,
      securitySettings: SecuritySettings(isBiometryEnabled: false),
      isSetupFinished: false
    )
    return signerInfo
  }
}
