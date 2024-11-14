import Foundation
import TonSwift
import CoreComponents

public protocol BatteryRechargeMethodsRepository {
  func getRechargeMethods(rechargeOnly: Bool, isTestnet: Bool) -> [BatteryRechargeMethod]
  func saveRechargeMethods(_methods: [BatteryRechargeMethod], rechargeOnly: Bool, isTestnet: Bool) throws
}

struct BatteryRechargeMethodsRepositoryImplementation: BatteryRechargeMethodsRepository {
  let fileSystemVault: FileSystemVault<[BatteryRechargeMethod], String>
  
  init(fileSystemVault: FileSystemVault<[BatteryRechargeMethod], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getRechargeMethods(rechargeOnly: Bool,
                          isTestnet: Bool) -> [BatteryRechargeMethod] {
    do {
      return try fileSystemVault.loadItem(key: key(rechargeOnly: rechargeOnly, isTestnet: isTestnet))
    } catch {
      return []
    }
  }
  
  func saveRechargeMethods(_methods: [BatteryRechargeMethod],
                           rechargeOnly: Bool,
                           isTestnet: Bool) throws {
    try fileSystemVault.saveItem(_methods, key: key(rechargeOnly: rechargeOnly, isTestnet: isTestnet))
  }
  
  private func key(rechargeOnly: Bool, isTestnet: Bool) -> String {
    let key = "recharge_methods\(rechargeOnly ? "_recharge_only" : "")\(isTestnet ? "_testnet" : "")"
    return key
  }
}
