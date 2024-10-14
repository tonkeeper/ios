import Foundation
import KeeperCore
import BigInt
import TonSwift

final class BatteryRefillRechargeMethodsModel {
  
  enum RechargeMethodItem {
    case token(token: Token, amount: BigUInt)
    case gift
    
    var identifier: String {
      switch self {
      case .token(let token, _):
        return token.identifier
      case .gift:
        return "gift_identifier"
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
  private let configurationStore: ConfigurationStore
  private let batteryService: BatteryService

  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStore,
       configurationStore: ConfigurationStore,
       batteryService: BatteryService) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.configurationStore = configurationStore
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
    
    let jettonItems = balance.jettonsBalance
      .filter { balanceJetton in
        balanceJetton.jettonBalance.quantity > 0 &&
        jettonMasterAddresses.contains(balanceJetton.jettonBalance.item.jettonInfo.address)
      }
      .sorted(by: { $0.converted > $1.converted })
      .map {
        RechargeMethodItem.token(token: .jetton($0.jettonBalance.item), amount: $0.jettonBalance.quantity)
      }
    
    var result = jettonItems
    if !tonRechargeMethods.isEmpty, balance.tonBalance.tonBalance.amount > 0 {
      result.append(.token(token: .ton, amount: BigUInt(balance.tonBalance.tonBalance.amount)))
    }
    
    if !result.isEmpty {
      result.append(.gift)
    }

    self.state = .idle(items: result)
  }
}
