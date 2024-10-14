import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize
import StoreKit

protocol BatteryRefillModuleOutput: AnyObject {
  
}

protocol BatteryRefillModuleInput: AnyObject {
  
}

protocol BatteryRefillViewModel: AnyObject {
  var didUpdateSnapshot: ((BatteryRefill.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func getInAppPurchaseCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
  func getListItemCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
  func purchaseItem(productIdentifier: String)
}

final class BatteryRefillViewModelImplementation: NSObject, BatteryRefillViewModel, BatteryRefillModuleOutput, BatteryRefillModuleInput {
  
  // MARK: - BatteryRefillViewModel

  var didUpdateSnapshot: ((BatteryRefill.Snapshot) -> Void)?
  
  func viewDidLoad() {
    iapItems = inAppPurchaseModel.items
    inAppPurchaseModel.loadProducts()
    inAppPurchaseModel.eventHandler = { [weak self] event in
      switch event {
      case .didUpdateItems(let items):
        self?.iapItems = items
      }
    }
    rechargeMethodsModelState = rechargeMethodsModel.state
    rechargeMethodsModel.stateHandler = { [weak self] state in
      self?.rechargeMethodsModelState = state
    }
    rechargeMethodsModel.loadMethods()
  }
  
  func getInAppPurchaseCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
    purchasesCellConfigurations[identifier]
  }
  
  func getListItemCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
    listItemCellConfigurations[identifier]
  }
  
  func purchaseItem(productIdentifier: String) {
    inAppPurchaseModel.startProcessing()
  }
  
  // MARK: - State
  
  private var iapItems = [BatteryIAPItem]() {
    didSet {
      didUpdateIAPModelState()
    }
  }
  private var rechargeMethodsModelState: BatteryRefillRechargeMethodsModel.State = .loading {
    didSet {
      didUpdateRechargeMethodsModelState()
    }
  }

  private var purchasesCellConfigurations = [String: TKListItemCell.Configuration]()
  private var listItemCellConfigurations = [String: TKListItemCell.Configuration]()

  // MARK: - Dependencies
  
  private let inAppPurchaseModel: BatteryRefillIAPModel
  private let rechargeMethodsModel: BatteryRefillRechargeMethodsModel
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(inAppPurchaseModel: BatteryRefillIAPModel,
       rechargeMethodsModel: BatteryRefillRechargeMethodsModel,
       decimalAmountFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.inAppPurchaseModel = inAppPurchaseModel
    self.rechargeMethodsModel = rechargeMethodsModel
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountFormatter = amountFormatter
  }

  private func didUpdateIAPModelState() {
    updateList()
  }
  
  private func didUpdateRechargeMethodsModelState() {
    updateList()
  }
  
  private func updateList() {
    let snapshot = createSnapshot()
    didUpdateSnapshot?(snapshot)
  }
  
  private func createSnapshot() -> BatteryRefill.Snapshot {
    var snapshot = BatteryRefill.Snapshot()

    createInAppPurchasesSnapshotSection(snapshot: &snapshot)
    createRechargeMethodsSnapshotSection(snapshot: &snapshot)
    createHistorySnapshotSection(snapshot: &snapshot)
    
    return snapshot
  }
  
  private func createInAppPurchasesSnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    var purchasesCellConfigurations = [String: TKListItemCell.Configuration]()
    var snapshotItems = [BatteryRefill.SnapshotItem]()
    for item in iapItems {
      snapshotItems.append(createInAppPurchaseSnapshotItem(item: item))
      purchasesCellConfigurations[item.pack.productIdentifier] = createInAppPurchaseCellConfiguration(item: item)
    }
    
    snapshot.appendSections([.inAppPurchases])
    snapshot.appendItems(snapshotItems, toSection: .inAppPurchases)
    self.purchasesCellConfigurations = purchasesCellConfigurations
  }

  private func createRechargeMethodsSnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    var cellConfigurations = [String: TKListItemCell.Configuration]()
    var snapshotItems = [BatteryRefill.SnapshotItem]()
    switch rechargeMethodsModelState {
    case .loading:
      break
    case .idle(let items):
      for item in items {
        snapshotItems.append(createRechargeMethodSnapshotItem(item: item))
        cellConfigurations[item.identifier] = createRechargeMethodCellConfiguration(item: item)
      }
    }

    snapshot.appendSections([.rechargeMethods])
    snapshot.appendItems(snapshotItems, toSection: .rechargeMethods)
    self.listItemCellConfigurations.merge(cellConfigurations, uniquingKeysWith: { $1 })
  }
  
  private func createHistorySnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    snapshot.appendSections([.history])
    snapshot.appendItems([.listItem(BatteryRefill.ListItem(
      identifier: .historyCellIdentifier,
      onSelection: {
        
      }))], toSection: .history)
    listItemCellConfigurations[.historyCellIdentifier] = createHistoryCellConfiguration()
  }
  
  private func createInAppPurchaseSnapshotItem(item: BatteryIAPItem) -> BatteryRefill.SnapshotItem {
    let buttonTitle: String
    switch item.state {
    case .amount(let amount):
      let value = decimalAmountFormatter.format(
        amount: amount.price,
        maximumFractionDigits: 2,
        currency: amount.currency)
      buttonTitle = value
    case .loading:
      buttonTitle = "Loading"
    }
    
    return .inAppPurchase(
      BatteryRefill.InAppPurchaseItem(
        identifier: item.pack.productIdentifier,
        batteryPercent: item.pack.batteryPercent,
        buttonTitle: buttonTitle,
        isEnable: item.isEnable
      )
    )
  }
  
  private func createRechargeMethodSnapshotItem(item: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> BatteryRefill.SnapshotItem {
    let listItem = BatteryRefill.ListItem(
      identifier: item.identifier,
      onSelection: {
        
      }
    )
    return .listItem(listItem)
  }
  
  private func createInAppPurchaseCellConfiguration(item: BatteryIAPItem) -> TKListItemCell.Configuration {
    let caption: String
    switch item.state {
    case .loading:
      caption = "Loading"
    case .amount(let amount):
      caption = "\(amount.charges) \(TKLocales.Battery.Refill.InAppPurchase.Caption.chargesCount(count: amount.charges))"
    }
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: item.pack.name),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
  }
  
  private func createRechargeMethodCellConfiguration(item: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> TKListItemCell.Configuration {
    let title: String
    let caption: String
    let iconViewConfiguration: TKListItemIconView.Configuration
    switch item {
    case .token(let token, let amount):
      title = "Recharge with \(token.symbol)"
      
      switch token {
      case .ton:
        iconViewConfiguration = .tonConfiguration()
      case .jetton(let jettonItem):
        iconViewConfiguration = .configuration(jettonInfo: jettonItem.jettonInfo)
      }
      
      caption = amountFormatter.formatAmount(
        amount,
        fractionDigits: token.fractionDigits,
        maximumFractionDigits: 2,
        symbol: token.symbol
      )
    case .gift:
      title = "Battery Gift"
      caption = "Share with friends"
      iconViewConfiguration = TKListItemIconView.Configuration(
        content: TKListItemIconView.Configuration.Content.image(TKImageView.Model(image: TKImage.image(.App.Battery.gift))),
        alignment: .center,
        cornerRadius: 12,
        backgroundColor: .clear,
        size: CGSize(width: 44, height: 44)
      )
    }
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: iconViewConfiguration,
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
  }
  
  private func createHistoryCellConfiguration() -> TKListItemCell.Configuration {
    let title = "Charges history"
    let caption = "Recharges and refunds"
    let iconViewConfiguration = TKListItemIconView.Configuration(
      content: TKListItemIconView.Configuration.Content.image(TKImageView.Model(image: TKImage.image(.App.Battery.history))),
      alignment: .center,
      cornerRadius: 12,
      backgroundColor: .clear,
      size: CGSize(width: 44, height: 44)
    )
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: iconViewConfiguration,
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
  }
}

private extension String {
  static let historyCellIdentifier = "history_item"
}
