import Foundation
import TonSwift
import CoreComponents

public protocol BatteryRechargeMethodsRepository {
  func getRechargeMethods(rechargeOnly: Bool) -> [BatteryRechargeMethod]
  func saveRechargeMethods(_methods: [BatteryRechargeMethod], rechargeOnly: Bool) throws
}

struct BatteryRechargeMethodsRepositoryImplementation: BatteryRechargeMethodsRepository {
  let fileSystemVault: FileSystemVault<[BatteryRechargeMethod], String>
  
  init(fileSystemVault: FileSystemVault<[BatteryRechargeMethod], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getRechargeMethods(rechargeOnly: Bool) -> [BatteryRechargeMethod] {
    do {
      return try fileSystemVault.loadItem(key: key(rechargeOnly: rechargeOnly))
    } catch {
      return []
    }
  }
  
  func saveRechargeMethods(_methods: [BatteryRechargeMethod], rechargeOnly: Bool) throws {
    try fileSystemVault.saveItem(_methods, key: key(rechargeOnly: rechargeOnly))
  }
  
  private func key(rechargeOnly: Bool) -> String {
    let key = "recharge_methods\(rechargeOnly ? "_recharge_only" : "")"
    return key
  }
}
