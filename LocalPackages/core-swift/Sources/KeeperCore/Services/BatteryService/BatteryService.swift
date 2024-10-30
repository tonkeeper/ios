import Foundation
import TonSwift
import TonAPI
import TKBatteryAPI
import BigInt

public protocol BatteryService {
  func loadBatteryBalance(wallet: Wallet, tonProofToken: String) async throws -> BatteryBalance
  func loadRechargeMethods(wallet: Wallet,
                           includeRechargeOnly: Bool) async throws -> [BatteryRechargeMethod]
  func loadBatteryConfig(wallet: Wallet) async throws -> Config
  func loadTransactionInfo(wallet: Wallet, boc: String, tonProofToken: String) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool)
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
  
  func loadBatteryConfig(wallet: Wallet) async throws -> Config {
    try await batteryAPIProvider
      .api(wallet.isTestnet)
      .getBatteryConfig()
  }
  
  func loadTransactionInfo(wallet: Wallet, boc: String, tonProofToken: String) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool) {
    let response = try await batteryAPIProvider
      .api(wallet.isTestnet)
      .emulate(tonProofToken: tonProofToken, boc: boc)
    
    let result = try JSONDecoder().decode(MessageConsequences.self, from: response.responseData)
    return (result, response.isBatteryAvailable)
  }
}
