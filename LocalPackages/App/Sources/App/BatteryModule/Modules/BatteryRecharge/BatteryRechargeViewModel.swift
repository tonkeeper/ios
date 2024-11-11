import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize
import BigInt

protocol BatteryRechargeModuleOutput: AnyObject {
  var didTapContinue: ((_ payload: BatteryRechargePayload) -> Void)? { get set }
  var didSelectTokenPicker: ((Token) -> Void)? { get set }
}

protocol BatteryRechargeModuleInput: AnyObject {
  func setToken(token: Token)
}

protocol BatteryRechargeViewModel: AnyObject {
  var didUpdateSnapshot: ((BatteryRecharge.Snapshot) -> Void)? { get set }
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateContinueButtonConfiguration: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdateTokenPickerButtonConfiguration: ((TokenPickerButton.Configuration) -> Void)? { get set }
  var didUpdateTokenPickerAction: (( @escaping () -> Void ) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BatteryRechargeViewModelImplementation: BatteryRechargeViewModel, BatteryRechargeModuleOutput, BatteryRechargeModuleInput {
  
  // MARK: - BatteryRechargeModuleOutput
  
  var didTapContinue: ((BatteryRechargePayload) -> Void)?
  var didSelectTokenPicker: ((Token) -> Void)?
  
  // MARK: - BatteryRechargeModuleInput
  
  func setToken(token: Token) {
    model.token = token
  }
  
  // MARK: - BatteryRechargeViewModel
  
  var didUpdateSnapshot: ((BatteryRecharge.Snapshot) -> Void)?
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateContinueButtonConfiguration: ((TKButton.Configuration) -> Void)?
  var didUpdateTokenPickerButtonConfiguration: ((TokenPickerButton.Configuration) -> Void)?
  var didUpdateTokenPickerAction: (( @escaping () -> Void ) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitle?(model.isGift ? TKLocales.Battery.Recharge.giftTitle : TKLocales.Battery.Recharge.title)
    didUpdateTokenPickerAction?({ [weak self] in
      guard let self else { return }
      didSelectTokenPicker?(model.token)
    })
    setupPromocode()
    setupRecipientInput()
    
    model.didUpdateIsContinueEnable = { [weak self] in
      self?.updateContinueButton()
    }
    model.didUpdateOptionItems = { [weak self] in
      self?.updateList()
    }
    model.didUpdateIsCustomInputEnable = { [weak self] in
      guard let self else { return }
      if !model.isCustomInputEnable {
        amountInputModuleInput.reset()
      }
      updateList()
    }
    model.didUpdateToken = { [weak self] in
      guard let self else { return }
      amountInputModuleInput.sourceUnit = model.token
      amountInputModuleInput.sourceBalance = model.balance
      amountInputModuleInput.destinationUnit = ChargeItem()
      didUpdateTokenPickerButtonConfiguration?(.createConfiguration(token: model.token))
    }
    
    model.didUpdateRate = { [weak self] in
      guard let self else { return }
      amountInputModuleInput.rate = model.tonChargeRate
    }
    model.didUpdateBalance = { [weak self] in
      guard let self else { return }
      amountInputModuleInput.sourceBalance = model.balance
    }

    amountInputModuleOutput.didUpdateSourceAmount = { [weak self] in
      guard let self else { return }
      model.amount = $0
    }
    
    model.start()
  }
 
  private var snapshot = BatteryRecharge.Snapshot()
  
  private let model: BatteryRechargeModel
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let amountInputModuleInput: AmountInputModuleInput
  private let amountInputModuleOutput: AmountInputModuleOutput
  private let promocodeOutput: BatteryPromocodeInputModuleOutput
  private let recipientInputOutput: RecipientInputModuleOutput
  
  init(model: BatteryRechargeModel, 
       amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter,
       amountInputModuleInput: AmountInputModuleInput,
       amountInputModuleOutput: AmountInputModuleOutput,
       promocodeOutput: BatteryPromocodeInputModuleOutput,
       recipientInputOutput: RecipientInputModuleOutput) {
    self.model = model
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountInputModuleInput = amountInputModuleInput
    self.amountInputModuleOutput = amountInputModuleOutput
    self.promocodeOutput = promocodeOutput
    self.recipientInputOutput = recipientInputOutput
  }
  
  private func updateList() {
    var snapshot = BatteryRecharge.Snapshot()
    
    setupRecipientSnapshotSection(snapshot: &snapshot)
    setupOptionsSection(snapshot: &snapshot)
    setupCustomInputSection(snapshot: &snapshot)
    setupPromocodeInputSection(snapshot: &snapshot)
    setupContinueButtonSection(snapshot: &snapshot)

    didUpdateSnapshot?(snapshot)
  }

  func setupOptionsSection(snapshot: inout BatteryRecharge.Snapshot) {
    var snapshotItems = [BatteryRecharge.SnapshotItem]()
    
    for item in model.optionsItems {
      let snapshotItem = createOptionSnapshotItem(option: item)
      snapshotItems.append(snapshotItem)
    }
    
    snapshot.appendSections([.options])
    snapshot.appendItems(snapshotItems, toSection: .options)
  }
  
  func setupPromocodeInputSection(snapshot: inout BatteryRecharge.Snapshot) {
    snapshot.appendSections([.promocode])
    snapshot.appendItems([.promocode], toSection: .promocode)
  }
  
  
  func setupRecipientSnapshotSection(snapshot: inout BatteryRecharge.Snapshot) {
    guard model.isGift else { return }
    snapshot.appendSections([.recipient])
    snapshot.appendItems([.recipient], toSection: .recipient)
  }
  
  func setupCustomInputSection(snapshot: inout BatteryRecharge.Snapshot) {
    guard model.isCustomInputEnable else {
      return
    }
    snapshot.appendSections([.customInput])
    snapshot.appendItems([.customInput], toSection: .customInput)
  }
  
  func setupContinueButtonSection(snapshot: inout BatteryRecharge.Snapshot) {
    snapshot.appendSections([.continueButton])
    snapshot.appendItems([.continueButton], toSection: .continueButton)
  }
  
  func createOptionSnapshotItem(option: BatteryRechargeModel.OptionItem) -> BatteryRecharge.SnapshotItem {
    let title = {
      switch option {
      case .prefilled(let prefilled):
        return "\(prefilled.chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: prefilled.chargesCount))"
      case .custom:
        return TKLocales.Battery.Recharge.СustomInput.title
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
        return TKLocales.Battery.Recharge.СustomInput.caption
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
    
    return BatteryRecharge.SnapshotItem.rechargeOption(
      BatteryRecharge.RechargeOptionItem(
        identifier: option.identifier,
        listCellConfiguration: cellConfiguration,
        isEnable: option.isEnable,
        batteryViewState: batteryViewState,
        onSelection: { [weak self] in
          self?.model.selectedOptionItem = option
        }
      )
    )
  }
  
  func updateContinueButton() {
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.continueAction))
    buttonConfiguration.isEnabled = model.isContinueEnable
    buttonConfiguration.action = { [weak self] in
      guard let self else { return }
      let payload = model.getConfirmationPayload()
      didTapContinue?(payload)
    }
    
    didUpdateContinueButtonConfiguration?(buttonConfiguration)
  }
  
  func setupPromocode() {
    promocodeOutput.didUpdateResolvingState = { [weak self] in
      switch $0 {
      case .success(let promocode):
        self?.model.promocode = promocode
      default:
        self?.model.promocode = nil
      }
    }
  }
  
  func setupRecipientInput() {
    recipientInputOutput.didResolveRecipient = { [weak self] recipient in
      self?.model.recipient = recipient
    }
  }
}
