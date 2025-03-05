import Foundation
import TKFeatureFlags
import KeeperCore
import BigInt
import TonSwift

final class BatteryRefillRechargeMethodsModel {
  
  enum RechargeMethodItem {
    case token(token: Token)
    case gift(token: Token)
    
    var identifier: String {
      switch self {
      case .token(let token):
        return token.identifier
      case .gift:
        return "gift_identifier"
      }
    }
    
    var token: Token {
      switch self {
      case .token(let token):
        return token
      case .gift(let token):
        return token
      }
    }
  }
  
  enum State {
    case loading
    case idle(items: [RechargeMethodItem])
  }
  
  var stateHandler: ((State) -> Void)?
  private(set) var state: State = .loading {
    didSet {
      stateHandler?(state)
    }
  }
  
  private var rechargeMethods = [RechargeMethodItem]()
  private var loadingTask: Task<Void, Never>?
  private var isLoading: Bool {
    loadingTask == nil
  }
  
  private let wallet: Wallet
  private let rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider
  
  init(wallet: Wallet,
       rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider) {
    self.wallet = wallet
    self.rechargeMethodsProvider = rechargeMethodsProvider
  }
  
  func loadMethods() {
    guard !TKFeatureFlags.provider.isBatteryCryptoRechargeDisable else {
      state = .idle(items: [])
      return
    }
    
    if let loadingTask = loadingTask {
      loadingTask.cancel()
    }
    let task = Task { [weak self] in
      guard let self else { return }
      let methods = await rechargeMethodsProvider.getAllRechargeMethods()
      await MainActor.run {
        self.rechargeMethods = methods
        self.loadingTask = nil
        self.state = .idle(items: methods)
      }
    }
    self.loadingTask = task
  }
//  
//  private func updateState() {
//    guard !TKFeatureFlags.provider.isBatteryCryptoRechargeDisable else {
//      state = .idle(items: [])
//      return
//    }
//    
//    let methods = rechargeMethodsProvider.getAllRechargeMethods()
////
////    guard let balance = balanceStore.getState()[wallet]?.balance else {
////      state = .idle(items: [])
////      return
////    }
////    
////    let rechargeMethods = rechargeMethods
////      .filter { $0.supportRecharge }
////    
////    var tonRechargeMethods = [BatteryRechargeMethod]()
////    var jettonRechargeMethods = [BatteryRechargeMethod]()
////    var jettonMasterAddresses = [Address]()
////    rechargeMethods.forEach {
////      switch $0.token {
////      case .ton: tonRechargeMethods.append($0)
////      case .jetton(let jetton):
////        jettonRechargeMethods.append($0)
////        jettonMasterAddresses.append(jetton.jettonMasterAddress)
////      }
////    }
////    
////    let balanceJettonItems = balance.jettonsBalance
////      .filter { balanceJetton in
////        balanceJetton.jettonBalance.quantity > 0 &&
////        jettonMasterAddresses.contains(balanceJetton.jettonBalance.item.jettonInfo.address)
////      }
////    
////    let items = jettonRechargeMethods.compactMap { rechargeMethod -> RechargeMethodItem? in
////      guard let jettonBalance = balanceJettonItems.first(where: { $0.jettonBalance.item.jettonInfo.address == rechargeMethod.jettonMasterAddress  }) else {
////        return nil
////      }
////      return RechargeMethodItem.token(
////        token: .jetton(jettonBalance.jettonBalance.item)
////      )
////    }
////    
////    var result = items
////    if !tonRechargeMethods.isEmpty, balance.tonBalance.tonBalance.amount > 0 {
////      result.append(.token(token: .ton))
////    }
////    if !result.isEmpty {
////      let giftItem = result[0]
////      result.append(.gift(token: giftItem.token))
////      self.state = .idle(items: result)
////    }
//  }
}
