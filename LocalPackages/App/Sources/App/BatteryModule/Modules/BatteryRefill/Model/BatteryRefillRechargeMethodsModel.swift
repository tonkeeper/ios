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
}
