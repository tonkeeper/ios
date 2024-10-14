import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize
import StoreKit

protocol BatteryRefillSupportedTransactionsModuleOutput: AnyObject {
  
}

protocol BatteryRefillSupportedTransactionsModuleInput: AnyObject {
  
}

protocol BatteryRefillSupportedTransactionsViewModel: AnyObject {
  var didUpdateSnapshot: ((BatteryRefillSupportedTransactions.Snapshot) -> Void)? { get set }
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BatteryRefillSupportedTransactionsViewModelImplementation: BatteryRefillSupportedTransactionsViewModel, BatteryRefillSupportedTransactionsModuleOutput, BatteryRefillSupportedTransactionsModuleInput {
  
  // MARK: - BatteryRefillSupportedTransactionsViewModel
  
  var didUpdateSnapshot: ((BatteryRefillSupportedTransactions.Snapshot) -> Void)?
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitleView?(
      TKUINavigationBarTitleView.Model(
        title: "Transactions"
      )
    )
    
    let configuration = configurationStore.getConfiguration()
    let snapshot = createSnapshot(configuration: configuration)
    didUpdateSnapshot?(snapshot)
  }
  
  private let configurationStore: ConfigurationStore
  
  init(configurationStore: ConfigurationStore) {
    self.configurationStore = configurationStore
  }
  
  private func createSnapshot(configuration: RemoteConfiguration) -> BatteryRefillSupportedTransactions.Snapshot {
    var snapshot = BatteryRefillSupportedTransactions.Snapshot()
    
    snapshot.appendSections([.listItems])
    let items = BatterySupportedTransaction.allCases.map { transaction in
      
      let transactionPrice: NSDecimalNumber? = {
        switch transaction {
        case .swap:
          return configuration.batteryMeanFeesPriceSwapDecimaNumber
        case .jetton:
          return configuration.batteryMeanFeesPriceJettonDecimaNumber
        case .nft:
          return configuration.batteryMeanFeesPriceNFTDecimaNumber
        }
      }()
      
      let chargesCount = calculateChargesAmount(transactionPrice: transactionPrice, fee: configuration.batteryMeanFeesDecimaNumber)
      let caption = transaction.caption(chargesCount: chargesCount)
      let cellConfiguration = TKListItemCell.Configuration(
        listItemContentViewConfiguration: TKListItemContentView.Configuration(
          textContentViewConfiguration: TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(title: transaction.name),
            captionViewsConfigurations: [
              TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2, numberOfLines: 0)
            ]
          )
        )
      )
      let snapshotItem = BatteryRefillSupportedTransactions.SnapshotItem(
        identifier: transaction.rawValue,
        cellConfiguration: cellConfiguration
      )
      return snapshotItem
    }
    snapshot.appendItems(items, toSection: .listItems)
    
    return snapshot
  }
  
  private func calculateChargesAmount(transactionPrice: NSDecimalNumber?, fee: NSDecimalNumber?) -> Int {
    guard let transactionPrice, let fee else { return 0 }
    return transactionPrice
      .dividing(by: fee, withBehavior: NSDecimalNumberHandler.dividingRoundBehaviour)
      .rounding(accordingToBehavior: NSDecimalNumberHandler.roundBehaviour)
      .intValue
  }
}

private extension NSDecimalNumberHandler {
  static var dividingRoundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 20,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
  
  static var roundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 0,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
}
