import UIKit
import KeeperCore
import TKCore
import BigInt
import TKLocalize

protocol SwapConfirmationModuleOutput: AnyObject {
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var swapDone: (() -> Void)? { get set }
}

protocol SwapConfirmationModuleInput: AnyObject {
}

protocol SwapConfirmationViewModel: AnyObject {
  var amountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  var imageLoader: ImageLoader { get }

  func viewDidLoad()
  var didUpdateModel: ((SwapConfirmationModel) -> Void)? { get set }
}

struct SwapConfirmationModel {
  struct SwapViewItem {
    let title: String
    var swapItem: SwapItem
    var amountString: String
    var amountInBaseCurrencyString: String
  }
  struct Button {
    var isActivity: Bool
    let action: (() -> Void)
  }
  
  var sellItem: SwapViewItem
  var buyItem: SwapViewItem
  var estimate: SwapEstimate?
  var minAskAmount: String?
  var liquidityFee: String?
  var button: Button
}

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput, SwapConfirmationModuleInput {
  // MARK: - SwapConfirmationModuleOutput
  var didRequireConfirmation: (() async -> Bool)?
  var swapDone: (() -> Void)?
  
  // MARK: - SwapConfirmationModuleInput

  // MARK: - SwapItemsViewModel
  
  private lazy var model = createModel()
  func viewDidLoad() {
    didUpdateModel?(model)
  }

  var didUpdateModel: ((SwapConfirmationModel) -> Void)?
  // MARK: - State
  
  private let swapConfirmationController: SwapConfirmationController
  private let walletsStore: WalletsStore

  // MARK: - Formatters
  
  let amountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = " "
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return amountInputFormatController
  }()
  
  func tokenFractionalDigits(token: SwapToken) -> Int {
    let fractionDigits: Int
    switch token {
    case .ton:
      fractionDigits = TonInfo.fractionDigits
    case .jetton(let item):
      fractionDigits = item.decimals
    }
    return fractionDigits
  }
  
  // MARK: - Dependencies
  
  let imageLoader = ImageLoader()

  // MARK: - Init
  private let defaultSellItem: SwapItem
  private let defaultBuyItem: SwapItem
  private let estimate: SwapEstimate
  init(sellItem: SwapItem,
       buyItem: SwapItem,
       estimate: SwapEstimate,
       swapConfirmationController: SwapConfirmationController,
       walletsStore: WalletsStore) {
    self.defaultSellItem = sellItem
    self.defaultBuyItem = buyItem
    self.estimate = estimate
    self.swapConfirmationController = swapConfirmationController
    self.walletsStore = walletsStore
  }
}

private extension SwapConfirmationViewModelImplementation {
  func createModel() -> SwapConfirmationModel {
    let model = SwapConfirmationModel(
      sellItem: SwapConfirmationModel.SwapViewItem(
        title: TKLocales.Swap.send,
        swapItem: defaultSellItem,
        amountString: swapConfirmationController.convertAmountToInputString(amount: defaultSellItem.amount, token: defaultSellItem.token),
        amountInBaseCurrencyString: ""
      ),
      buyItem: SwapConfirmationModel.SwapViewItem(
        title: TKLocales.Swap.receive,
        swapItem: defaultBuyItem,
        amountString: swapConfirmationController.convertAmountToInputString(amount: defaultBuyItem.amount, token: defaultBuyItem.token),
        amountInBaseCurrencyString: ""
      ),
      minAskAmount: swapConfirmationController.convertAmountToInputString(amount: BigUInt(estimate.minAskUnits ?? 0),
                                                                          token: defaultBuyItem.token),
      liquidityFee: swapConfirmationController.convertAmountToInputString(amount: BigUInt(estimate.feeUnits ?? 0),
                                                                          token: defaultBuyItem.token),
      button: SwapConfirmationModel.Button(
        isActivity: false,
        action: { [weak self] in
          Task { [weak self] in
            let isSuccess = await self?.sendTransaction()
            await MainActor.run { [weak self] in
              if isSuccess == true {
                self?.swapDone?()
              } else {
                self?.model.button.isActivity = true
                self?.didUpdateModel?(self!.model)
              }
            }
          }
        }
      )
    )
    Task {
      let (sellCurrency, buyCurrency) = await self.swapConfirmationController.getConvertedValues()
      self.model.sellItem.amountInBaseCurrencyString = sellCurrency
      self.model.buyItem.amountInBaseCurrencyString = buyCurrency
      await MainActor.run {
        didUpdateModel?(self.model)
      }
    }
    return model
  }
  
  func sendTransaction() async -> Bool {
    if swapConfirmationController.isNeedToConfirm() {
      let isConfirmed = await didRequireConfirmation?() ?? false
      guard isConfirmed else { return false }
    }
    do {
      model.button.isActivity = true
      await MainActor.run {
        didUpdateModel?(model)
      }
      try await swapConfirmationController.sendTransaction(sellItem: self.defaultSellItem,
                                                           buyItem: self.defaultBuyItem,
                                                           estimate: self.estimate)
      return true
    } catch {
      return false
    }
  }

}
