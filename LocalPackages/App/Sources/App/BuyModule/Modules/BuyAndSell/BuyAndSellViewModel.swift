import UIKit
import KeeperCore
import TKCore
import TKUIKit
import TKLocalize
import BigInt

protocol BuyAndSellViewModelOutput: AnyObject {
  var didContinue: ((TransactionAmountModel) -> Void)? { get set }
}

protocol BuyAndSellViewModel: AnyObject {
  var didUpdateModel: ((BuyAndSellView.Model) -> Void)? { get set }
  
  var sendAmountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmount(_ string: String)
  func didTapContinueButton()
  func didSelectSegment(at index: Int)
}

final class BuyAndSellViewModelImplementation: BuyAndSellViewModel, BuyAndSellViewModelOutput {
  
  // MARK: - BuyListModuleOutput
  
  var didContinue: ((TransactionAmountModel) -> Void)?
  
  // MARK: - BuyAndSellViewModel
  
  var didUpdateModel: ((BuyAndSellView.Model) -> Void)?
    
  private let buyListController: BuyListController
  private let currencyStore: CurrencyStore
  
  init(buyListController: BuyListController, currencyStore: CurrencyStore) {
    self.buyListController = buyListController
    self.currencyStore = currencyStore
  }
  
  // MARK: - State
  
  private var amountInput = ""
  private var convertedValue = ""
  private var amount: BigUInt = 0
  private var mode: FiatMethodCategoryType = .buy {
    didSet {
      guard mode != oldValue else { return }
      update()
    }
  }
  
  private var isAmountValid: Bool = false {
    didSet {
      guard isAmountValid != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnabled: Bool = false {
    didSet {
      guard isContinueEnabled != oldValue else { return }
      update()
    }
  }
  
  func viewDidLoad() {
    update()
    updateConverted()
    
    Task {
      await startObservations()
    }
  }
  
  private func startObservations() async {
    _ = await currencyStore.addEventObserver(self) { [weak self] observer, event in
      switch event {
      case .didChangeCurrency:
        self?.updateConverted()
      }
    }
  }
  
  func didInputAmount(_ string: String) {
    guard string != amountInput else { return }
    let unformatted = self.sendAmountTextFieldFormatter.unformatString(string) ?? ""
    let amount = buyListController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: TonInfo.fractionDigits)
    
    switch mode {
    case .buy:
      let isAmountValid = !amount.amount.isZero
      self.amountInput = unformatted
      self.amount = amount.amount
      self.isAmountValid = isAmountValid
      updateConverted()
      update()
    case .sell:
      Task {
        let isAmountValid = await buyListController.isAmountAvailableToSend(amount: amount.amount, token: .ton) && !amount.amount.isZero
        await MainActor.run {
          self.amountInput = unformatted
          self.amount = amount.amount
          self.isAmountValid = isAmountValid
          updateConverted()
          update()
        }
      }
    }
  }
  
  func didTapContinueButton() {
    let transactionModel = TransactionAmountModel(type: mode, amount: amount)
    didContinue?(transactionModel)
  }
  
  func didSelectSegment(at index: Int) {
    mode = FiatMethodCategoryType.allCases[index]
    print(mode)
  }
  
  // MARK: - Formatters
  
  let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let maximumIntegerDigits = 9
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = ","
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = maximumIntegerDigits
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter,
      maximumIntegerDigits: maximumIntegerDigits
    )
    amountInputFormatController.shouldUpdateCursorLocation = false
    return amountInputFormatController
  }()
  
  private func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  private func updateConverted() {
    Task {
      let converted = await buyListController.convertTokenAmountToCurrency(amount)
      await MainActor.run {
        self.convertedValue = converted
        update()
      }
    }
  }
}

private extension BuyAndSellViewModelImplementation {
  func createModel() -> BuyAndSellView.Model {
    let amount = BuyAndSellView.Model.Amount(placeholder: "0", text: sendAmountTextFieldFormatter.formatString(amountInput) ?? "")
    
    return BuyAndSellView.Model(
      isContinueButtonEnabled: self.isAmountValid,
      minAmountDisclaimer: TKLocales.Buy.min_amount(50),
      amount: amount,
      convertedAmount: convertedValue
    )
  }
}
