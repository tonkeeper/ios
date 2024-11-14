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
    
    let snapshot = createSnapshot(configuration: configuration)
    didUpdateSnapshot?(snapshot)
  }
  
  private let wallet: Wallet
  private let configuration: Configuration
  
  init(wallet: Wallet,
       configuration: Configuration) {
    self.wallet = wallet
    self.configuration = configuration
  }
  
  private func createSnapshot(configuration: Configuration) -> BatteryRefillSupportedTransactions.Snapshot {
    var snapshot = BatteryRefillSupportedTransactions.Snapshot()
    
    snapshot.appendSections([.listItems])
    let items = BatterySupportedTransaction.allCases.map { transaction in
      
      let transactionPrice: NSDecimalNumber? = {
        switch transaction {
        case .swap:
          return configuration.batteryMeanFeesPriceSwapDecimaNumber(isTestnet: wallet.isTestnet)
        case .jetton:
          return configuration.batteryMeanFeesPriceJettonDecimaNumber(isTestnet: wallet.isTestnet)
        case .nft:
          return configuration.batteryMeanFeesPriceNFTDecimaNumber(isTestnet: wallet.isTestnet)
        }
      }()
      
      let chargesCount = calculateChargesAmount(transactionPrice: transactionPrice, 
                                                fee: configuration.batteryMeanFeesDecimaNumber(isTestnet: wallet.isTestnet))
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
