import Foundation
import KeeperCore
import BigInt
import TonSwift

final class BatteryRefillRechargeMethodsModel {
  
  enum RechargeMethodItem {
    case token(token: Token, amount: BigUInt, rate: NSDecimalNumber?)
    case gift(token: Token, rate: NSDecimalNumber?)
    
    var identifier: String {
      switch self {
      case .token(let token, _, _):
        return token.identifier
      case .gift:
        return "gift_identifier"
      }
    }
    
    var token: Token {
      switch self {
      case .token(let token, _, _):
        return token
      case .gift(let token, _):
        return token
      }
    }
    
    var rate: NSDecimalNumber? {
      switch self {
      case .token(_, _, let rate):
        return rate
      case .gift(_, let rate):
        return rate
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
  
  private var rechargeMethods = [BatteryRechargeMethod]()
  private var loadingTask: Task<Void, Never>?
  private var isLoading: Bool {
    loadingTask == nil
  }
  
  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStore
  private let configuration: Configuration
  private let batteryService: BatteryService
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStore,
       configuration: Configuration,
       batteryService: BatteryService) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.configuration = configuration
    self.batteryService = batteryService
  }
  
  func loadMethods() {
    if let loadingTask = loadingTask {
      loadingTask.cancel()
    }
    let task = Task {
      let methods: [BatteryRechargeMethod] = await {
        (try? await batteryService.loadRechargeMethods(wallet: wallet, includeRechargeOnly: false)) ?? []
      }()
      await MainActor.run {
        self.rechargeMethods = methods
        self.loadingTask = nil
        updateState()
      }
    }
    self.loadingTask = task
    updateState()
  }
  
  private func updateState() {
    guard let balance = balanceStore.getState()[wallet]?.balance else {
      state = .idle(items: [])
      return
    }
    
    let rechargeMethods = rechargeMethods
      .filter { $0.supportRecharge }
    
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
        balanceJetton.jettonBalance.quantity > 0 &&
        jettonMasterAddresses.contains(balanceJetton.jettonBalance.item.jettonInfo.address)
      }
    
    let items = jettonRechargeMethods.compactMap { rechargeMethod -> RechargeMethodItem? in
      guard let jettonBalance = balanceJettonItems.first(where: { $0.jettonBalance.item.jettonInfo.address == rechargeMethod.jettonMasterAddress  }) else {
        return nil
      }
      return RechargeMethodItem.token(
        token: .jetton(jettonBalance.jettonBalance.item),
        amount: jettonBalance.jettonBalance.quantity,
        rate: rechargeMethod.rateDecimalNumber
      )
    }
    
    var result = items
    if !tonRechargeMethods.isEmpty, balance.tonBalance.tonBalance.amount > 0 {
      result.append(.token(token: .ton, amount: BigUInt(balance.tonBalance.tonBalance.amount), rate: tonRechargeMethods.first?.rateDecimalNumber))
    }
    if !result.isEmpty {
      let giftItem = result[0]
      result.append(.gift(token: giftItem.token, rate: giftItem.rate))
      self.state = .idle(items: result)
    }
  }
}
