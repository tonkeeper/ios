import Foundation
import TonSwift
import TKBatteryAPI
import BigInt

public protocol BatteryService {
  func loadBatteryBalance(wallet: Wallet, tonProofToken: String) async throws -> BatteryBalance
  func loadRechargeMethods(wallet: Wallet,
                           includeRechargeOnly: Bool) async throws -> [BatteryRechargeMethod]
}

final class BatteryServiceImplementation: BatteryService {
  
  private let batteryAPIProvider: BatteryAPIProvider
  
  init(batteryAPIProvider: BatteryAPIProvider) {
    self.batteryAPIProvider = batteryAPIProvider
  }
  
  func loadBatteryBalance(wallet: Wallet,
                          tonProofToken: String) async throws -> BatteryBalance {
    let batteryBalance = try await batteryAPIProvider
      .api(wallet.isTestnet)
      .getBalance(tonProofToken: tonProofToken)
        
    return batteryBalance
  }
  
  func loadRechargeMethods(wallet: Wallet,
                           includeRechargeOnly: Bool) async throws -> [BatteryRechargeMethod] {
    let methods = try await batteryAPIProvider
      .api(wallet.isTestnet)
      .getRechargeMethos(includeRechargeOnly: includeRechargeOnly)
    
    return methods
  }
}
