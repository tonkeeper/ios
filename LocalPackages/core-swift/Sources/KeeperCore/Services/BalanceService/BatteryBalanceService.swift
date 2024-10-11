import Foundation
import TonSwift
import TonAPI
import BigInt

protocol BatteryBalanceService {
  func loadBatteryBalance(wallet: Wallet, tonProofToken: String) async throws -> BatteryBalance
}

final class BatteryBalanceServiceImplementation: BatteryBalanceService {
  
  private let batteryAPIProvider: BatteryAPIProvider
  
  init(batteryAPIProvider: BatteryAPIProvider) {
    self.batteryAPIProvider = batteryAPIProvider
  }
  
  func loadBatteryBalance(wallet: Wallet, tonProofToken: String) async throws -> BatteryBalance {
    let batteryBalance = try await batteryAPIProvider.api(wallet.isTestnet).getBalance(tonProofToken: tonProofToken)
        
    return batteryBalance
  }
}
