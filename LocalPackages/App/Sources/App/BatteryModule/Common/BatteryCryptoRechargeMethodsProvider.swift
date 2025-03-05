import Foundation
import KeeperCore
import TonSwift

actor BatteryCryptoRechargeMethodsProvider {
  
  private var loadRechargeMethodsTask: Task<[BatteryRechargeMethod], Never>?
  private var balanceLoadTask: Task<KeeperCore.WalletBalance, Swift.Error>?
  
  private let wallet: Wallet
  private let balanceService: BalanceService
  private let batteryService: BatteryService
  
  init(wallet: Wallet,
       balanceService: BalanceService,
       batteryService: BatteryService) {
    self.wallet = wallet
    self.balanceService = balanceService
    self.batteryService = batteryService
  }
  
  func getAllRechargeMethods() async  -> [BatteryRefillRechargeMethodsModel.RechargeMethodItem] {
    let rechargeMethods = await loadRechargeMethods()
      .filter { $0.supportRecharge }
    
    guard let balance = try? await loadBalance().balance else { return [] }

    var tonRechargeMethods = [BatteryRechargeMethod]()
    var jettonRechargeMethods = [BatteryRechargeMethod]()
    var jettonMasterAddresses = [Address]()
    rechargeMethods.forEach {
      switch $0.token {
      case .ton: tonRechargeMethods.append($0)
      case .jetton(let jetton):
        jettonRechargeMethods.append($0)
        jettonMasterAddresses.append(jetton.jettonMasterAddress)
      }
    }
    
    let balanceJettonItems = balance.jettonsBalance
      .filter { balanceJetton in
        balanceJetton.quantity > 0 &&
        jettonMasterAddresses.contains(balanceJetton.item.jettonInfo.address)
      }
    
    let items = jettonRechargeMethods.compactMap { rechargeMethod -> BatteryRefillRechargeMethodsModel.RechargeMethodItem? in
      guard let jettonBalance = balanceJettonItems.first(where: { $0.item.jettonInfo.address == rechargeMethod.jettonMasterAddress  }) else {
        return nil
      }
      return BatteryRefillRechargeMethodsModel.RechargeMethodItem.token(
        token: .jetton(jettonBalance.item)
      )
    }
    
    var result = items
    if !tonRechargeMethods.isEmpty, balance.tonBalance.amount > 0 {
      result.append(.token(token: .ton))
    }
    if !result.isEmpty {
      let giftItem = result[0]
      result.append(.gift(token: giftItem.token))
    }
    
    return result
  }
  
  func getRechargeMethod(jettonMasterAddress: Address) async -> BatteryRefillRechargeMethodsModel.RechargeMethodItem? {
    let rechargeMethods = await loadRechargeMethods()
      .filter { $0.supportRecharge }
    
    guard let balance = try? await loadBalance().balance else { return nil }
    
    guard let rechargeMethod = rechargeMethods.first(where: { $0.jettonMasterAddress == jettonMasterAddress }),
          case let .jetton(jetton) = rechargeMethod.token,
          let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo.address == jetton.jettonMasterAddress }) else {
      return nil
    }
    
    return .token(token: .jetton(jettonBalance.item))
  }
  
  private func loadRechargeMethods() async -> [BatteryRechargeMethod] {
    if let task = loadRechargeMethodsTask {
      return await task.value
    }
    
    let task = Task { [wallet, batteryService] in
      defer {
        self.loadRechargeMethodsTask = nil
      }
      do {
        let methods = try await batteryService.loadRechargeMethods(wallet: wallet, includeRechargeOnly: false)
        try Task.checkCancellation()
        return methods
      } catch {
        return []
      }
    }
    
    loadRechargeMethodsTask = task
    
    return await task.value
  }
  
  private func loadBalance() async throws -> KeeperCore.WalletBalance {
    if let task = balanceLoadTask {
      return try await task.value
    }
    
    let task = Task { [wallet, balanceService] in
      defer {
        balanceLoadTask = nil
      }
      return try await balanceService.loadWalletBalance(wallet: wallet, currency: .USD)
    }
    
    balanceLoadTask = task
    
    return try await task.value
  }
}
