import Foundation
import TonSwift
import TonAPI
import TKBatteryAPI
import BigInt

public protocol BatteryService {
  func loadBatteryBalance(wallet: Wallet, tonProofToken: String) async throws -> BatteryBalance
  func loadRechargeMethods(wallet: Wallet,
                           includeRechargeOnly: Bool) async throws -> [BatteryRechargeMethod]
  func getRechargeMethods(wallet: Wallet, includeRechargeOnly: Bool) -> [BatteryRechargeMethod]
  func loadBatteryConfig(wallet: Wallet) async throws -> Config
  func loadTransactionInfo(wallet: Wallet, boc: String, tonProofToken: String) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool)
  func sendTransaction(wallet: Wallet, boc: String, tonProofToken: String) async throws
  func makePurchase(wallet: Wallet, tonProofToken: String, transactionId: String, promocode: String?) async throws -> IOSBatteryPurchaseStatus
  func verifyPromocode(wallet: Wallet, promocode: String) async throws
}

final class BatteryServiceImplementation: BatteryService {
  
  private let batteryAPIProvider: BatteryAPIProvider
  private let rechargeMethodsRepository: BatteryRechargeMethodsRepository
  
  init(batteryAPIProvider: BatteryAPIProvider,
       rechargeMethodsRepository: BatteryRechargeMethodsRepository) {
    self.batteryAPIProvider = batteryAPIProvider
    self.rechargeMethodsRepository = rechargeMethodsRepository
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
    
    var ton = [BatteryRechargeMethod]()
    var usdt = [BatteryRechargeMethod]()
    var other = [BatteryRechargeMethod]()
    for method in methods {
      switch method.token {
      case .ton:
        ton.append(method)
      case .jetton(let jetton):
        if jetton.jettonMasterAddress == JettonMasterAddress.tonUSDT {
          usdt.append(method)
        } else {
          other.append(method)
        }
      }
    }

    let sortedMethods = usdt + other + ton
    
    try? rechargeMethodsRepository.saveRechargeMethods(
      _methods: sortedMethods,
      rechargeOnly: includeRechargeOnly,
      isTestnet: wallet.isTestnet
    )
    return sortedMethods
  }
  
  func getRechargeMethods(wallet: Wallet,
                          includeRechargeOnly: Bool) -> [BatteryRechargeMethod] {
    rechargeMethodsRepository.getRechargeMethods(
      rechargeOnly: includeRechargeOnly,
      isTestnet: wallet.isTestnet
    )
  }
  
  func loadBatteryConfig(wallet: Wallet) async throws -> Config {
    try await batteryAPIProvider
      .api(wallet.isTestnet)
      .getBatteryConfig()
  }
  
  func loadTransactionInfo(wallet: Wallet,
                           boc: String,
                           tonProofToken: String) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool) {
    let response = try await batteryAPIProvider
      .api(wallet.isTestnet)
      .emulate(tonProofToken: tonProofToken, boc: boc)
    
    let result = try JSONDecoder().decode(MessageConsequences.self, from: response.responseData)
    return (result, response.isBatteryAvailable)
  }
  
  func sendTransaction(wallet: Wallet, boc: String, tonProofToken: String) async throws {
    try await batteryAPIProvider
      .api(wallet.isTestnet)
      .sendMessage(tonProofToken: tonProofToken, boc: boc)
  }
  
  func makePurchase(wallet: Wallet, tonProofToken: String, transactionId: String, promocode: String?) async throws -> IOSBatteryPurchaseStatus {
    try await batteryAPIProvider
      .api(wallet.isTestnet)
      .makePurchase(tonProofToken: tonProofToken, transactionId: transactionId, promocode: promocode)
  }
  
  func verifyPromocode(wallet: Wallet, promocode: String) async throws {
    try await batteryAPIProvider
      .api(wallet.isTestnet)
      .verifyPromocode(promocode: promocode)
  }
}
