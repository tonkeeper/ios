import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize
import BigInt

protocol BatteryRechargeModuleOutput: AnyObject {
  var didTapContinue: ((_ payload: BatteryRechargePayload) -> Void)? { get set }
}

protocol BatteryRechargeModuleInput: AnyObject {
  
}

protocol BatteryRechargeViewModel: AnyObject {
  var didUpdateSnapshot: ((BatteryRecharge.Snapshot) -> Void)? { get set }
  var didUpdateTitle: ((String) -> Void)? { get set }
  
  func viewDidLoad()
  func listCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
  var continueButtonCellConfiguration: TKButtonCell.Model? { get }
}

final class BatteryRechargeViewModelImplementation: BatteryRechargeViewModel, BatteryRechargeModuleOutput, BatteryRechargeModuleInput {
  
  // MARK: - BatteryRechargeModuleOutput
  
  var didTapContinue: ((BatteryRechargePayload) -> Void)?
  
  // MARK: - BatteryRechargeViewModel
  
  var didUpdateSnapshot: ((BatteryRecharge.Snapshot) -> Void)?
  var didUpdateTitle: ((String) -> Void)?
  
  func viewDidLoad() {
    numberFormatter.maximumFractionDigits = 2
    didUpdateTitle?(configuration.title)
    modelState = model.state
    updateList(updateItems: true, updateButton: true)
    model.didUpdateState = { [weak self] state in
      self?.modelState = state
    }
  }
  
  func listCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
    listCellConfigurations[identifier]
  }
  
  private var modelState = BatteryRechargeModel.State(items: [], isContinueButtonEnable: false) {
    didSet {
      let updateItems = modelState.items != oldValue.items
      let updateButton = modelState.isContinueButtonEnable != oldValue.isContinueButtonEnable
      updateList(updateItems: updateItems, updateButton: updateButton)
    }
  }
  
  private var listCellConfigurations = [String: TKListItemCell.Configuration]()
  private(set) var continueButtonCellConfiguration: TKButtonCell.Model?
  
  private var snapshot = BatteryRecharge.Snapshot()
  
  private let model: BatteryRechargeModel
  private let configuration: BatteryRechargeViewModelConfiguration
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let numberFormatter = NumberFormatter()
  
  init(model: BatteryRechargeModel, 
       configuration: BatteryRechargeViewModelConfiguration,
       amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter) {
    self.model = model
    self.configuration = configuration
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  private func updateList(updateItems: Bool, updateButton: Bool) {
    var snapshot = self.snapshot
    if updateItems {
      createOptionsSection(snapshot: &snapshot)
    }
    if updateButton {
      createContinueButtonSection(snapshot: &snapshot)
    }
    self.snapshot = snapshot
    
    didUpdateSnapshot?(snapshot)
  }

  func createOptionsSection(snapshot: inout BatteryRecharge.Snapshot) {
    snapshot.deleteSections([.options])
    var snapshotItems = [BatteryRecharge.SnapshotItem]()
    
    for item in modelState.items {
      let snapshotItem = createOptionSnapshotItem(option: item)
      snapshotItems.append(snapshotItem)
    }
    
    snapshot.appendSections([.options])
    snapshot.appendItems(snapshotItems, toSection: .options)
    snapshot.reloadItems(snapshotItems)
  }
  
  func createOptionSnapshotItem(option: BatteryRechargeModel.OptionItem) -> BatteryRecharge.SnapshotItem {
    let title = {
      switch option {
      case .prefilled(let prefilled):
        return "\(prefilled.chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: prefilled.chargesCount))"
      case .custom:
        return "Other"
      }
    }()
    
    let caption = {
      switch option {
      case .prefilled(let prefilled):
        let tokenFormatted = amountFormatter.formatAmount(
          prefilled.tokenAmount,
          fractionDigits: prefilled.tokenDigits,
          maximumFractionDigits: 2,
          symbol: prefilled.tokenSymbol
        )
        let fiatFormatted = decimalAmountFormatter.format(
          amount: prefilled.fiatAmount,
          maximumFractionDigits: 2,
          currency: prefilled.currency)
        let result = "\(tokenFormatted) · \(fiatFormatted) "
        return result
      case .custom:
        return "Enter amount manually"
      }
    }()
    
    let batteryViewState: BatteryView.State = {
      switch option {
      case .prefilled(let prefilled):
        return .fill(prefilled.batteryPercent)
      case .custom:
        return .emptyTinted
      }
    }()
    
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
    
    listCellConfigurations[option.identifier] = cellConfiguration
    
    
    return BatteryRecharge.SnapshotItem.listItem(
      BatteryRecharge.ListItem(
        identifier: option.identifier,
        isEnable: option.isEnable,
        batteryViewState: batteryViewState,
        onSelection: { [weak self] in
          self?.model.amount = {
            switch option {
            case .prefilled(let prefilled):
              return prefilled.tokenAmount
            case .custom:
              return 0
            }
          }()
        }
      )
    )
  }
  
  func createContinueButtonSection(snapshot: inout BatteryRecharge.Snapshot) {
    snapshot.deleteSections([.continueButton])
    
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Continue"))
    buttonConfiguration.isEnabled = modelState.isContinueButtonEnable
    buttonConfiguration.action = { [weak self] in
      guard let self else { return }
      let payload = model.getConfirmationPayload()
      didTapContinue?(payload)
    }
    
    continueButtonCellConfiguration = TKButtonCell.Model(
      id: "continue_button",
      configuration: buttonConfiguration,
      padding: .zero,
      mode: .full
    )

    snapshot.appendSections([.continueButton])
    snapshot.appendItems([.continueButton])
    snapshot.reloadItems([.continueButton])
  }
}
