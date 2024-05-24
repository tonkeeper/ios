import UIKit
import KeeperCore
import TKCore
import BigInt
import TKLocalize

protocol SwapItemsModuleOutput: AnyObject {
  var didContinueSwap: ((SwapModel, SwapEstimate) -> Void)? { get set }
  var chooseTokenTapped: ((Wallet, Int) -> Void)? { get set }
  var settingsTapped: (() -> Void)? { get set }
}

protocol SwapItemsModuleInput: AnyObject {
  func update(with settings: SwapSettings)
  func updateWithToken(_ token: SwapToken, position: Int)
}

protocol SwapItemsViewModel: AnyObject {
  var didUpdateModel: ((SwapItemsModel) -> Void)? { get set }
  
  var amountTextFieldFormatter: SendAmountTextFieldFormatter { get }
  
  var imageLoader: ImageLoader { get }

  func viewDidLoad()
  func didTapSellItemTokenPicker()
  func didTapBuyItemTokenPicker()
  func didInputSellAmount(_ text: String)
  func didInputBuyAmount(_ text: String)
  func didTapMax()
  func didTapReverse()
  func didTapSettings()
}

struct SwapItemsModel {
  struct SwapViewItem {
    let title: String
    var swapItem: SwapItem?
    var amountString: String
    var balanceString: String
  }
  struct Button {
    var title: String
    var isEnabled: Bool
    var isActivity: Bool
    let action: (() -> Void)
  }
  
  var assets: [Asset]?
  var sellItem: SwapViewItem
  var buyItem: SwapViewItem
  var slippage: Float
  var estimate: SwapEstimate?
  var minAskAmount: String?
  var liquidityFee: String?
  var button: Button
}

final class SwapItemsViewModelImplementation: SwapItemsViewModel, SwapItemsModuleOutput, SwapItemsModuleInput {
  // MARK: - SwapItemsModuleOutput
  
  var didContinueSwap: ((SwapModel, SwapEstimate) -> Void)?
  var chooseTokenTapped: ((Wallet, Int) -> Void)?
  var settingsTapped: (() -> Void)?
  
  // MARK: - SwapItemsModuleInput
  func update(with settings: SwapSettings) {
    model.slippage = settings.slippage
  }

  func updateWithToken(_ token: SwapToken, position: Int) {
    if position == 1 {
      model.sellItem.swapItem = SwapItem(token: token, amount: 0)
    } else {
      model.buyItem.swapItem = SwapItem(token: token, amount: 0)
      model.buyItem.amountString = ""
    }
    Task {
      if let sellItem = model.sellItem.swapItem {
        let amountString = await swapItemsController.convertAmountToInputString(
          amount: swapItemsController.getAmountAvailable(symbol: sellItem.symbol),
          token: model.sellItem.swapItem!.token
        )
        model.sellItem.balanceString = "\(TKLocales.Swap.balance): \(amountString) \(sellItem.symbol)"
      } else {
        model.sellItem.balanceString = ""
      }
      if let buyItem = model.buyItem.swapItem {
        let amountString = await swapItemsController.convertAmountToInputString(
          amount: swapItemsController.getAmountAvailable(symbol: buyItem.symbol),
          token: buyItem.token
        )
        model.buyItem.balanceString = "\(TKLocales.Swap.balance): \(amountString) \(buyItem.symbol)"
      } else {
        model.buyItem.balanceString = ""
      }
      await updateEstimations(changePosition: 1)
    }
  }
  
  // MARK: - SwapItemsViewModel
  
  private lazy var model = createModel()
  func viewDidLoad() {
    didUpdateModel?(model)
    Task {
      let assetList = try? await swapItemsController.loadAssets()
      await MainActor.run {
        model.assets = assetList
        didUpdateModel?(model)
      }
    }
  }

  var didUpdateModel: ((SwapItemsModel) -> Void)?

  func didTapSellItemTokenPicker() {
    chooseTokenTapped?(swapItemsController.wallet, 1)
  }
  
  func didTapBuyItemTokenPicker() {
    chooseTokenTapped?(swapItemsController.wallet, 2)
  }
  
  func didInputSellAmount(_ text: String) {
    guard let swapItem = model.sellItem.swapItem else {
      return
    }
    Task {
      let unformatted = self.amountTextFieldFormatter.unformatString(text) ?? ""
      let amount = swapItemsController.convertInputStringToAmount(input: unformatted,
                                                                  targetFractionalDigits: tokenFractionalDigits(token: swapItem.token))
      /*let isAmountValid = await swapItemsController.isAmountAvailableToSend(amount: amount.amount, symbol: sellItem.symbol) && !amount.amount.isZero*/
      
      self.model.sellItem.swapItem?.amount = amount.amount
      amountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: swapItem.token)
      self.model.sellItem.amountString = amountTextFieldFormatter.formatString(unformatted) ?? ""

      await updateEstimations(changePosition: 1)
    }
  }
  
  func didInputBuyAmount(_ text: String) {
    guard let swapItem = self.model.buyItem.swapItem else {
      return
    }
    Task {
      let unformatted = self.amountTextFieldFormatter.unformatString(text) ?? ""
      let amount = swapItemsController.convertInputStringToAmount(input: unformatted,
                                                                  targetFractionalDigits: tokenFractionalDigits(token: swapItem.token))
      /*let isAmountValid = await swapItemsController.isAmountAvailableToSend(amount: amount.amount, symbol: sellItem.symbol) && !amount.amount.isZero*/
      
      self.model.buyItem.swapItem?.amount = amount.amount
      amountTextFieldFormatter.maximumFractionDigits = tokenFractionalDigits(token: swapItem.token)
      self.model.buyItem.amountString = amountTextFieldFormatter.formatString(unformatted) ?? ""

      await updateEstimations(changePosition: 2)
    }
  }
  
  func didTapMax() {
    guard let swapItem = model.sellItem.swapItem else {
      return
    }
    Task {
      model.sellItem.swapItem?.amount = await swapItemsController.getAmountAvailable(symbol: swapItem.symbol)
      model.sellItem.amountString = await swapItemsController.convertAmountToInputString(
        amount: swapItemsController.getAmountAvailable(symbol: swapItem.symbol),
        token: swapItem.token
      )
      await updateEstimations(changePosition: 1)
    }
  }
  
  func didTapReverse() {
    (model.sellItem.swapItem, model.buyItem.swapItem) = (model.buyItem.swapItem, model.sellItem.swapItem)
    (model.sellItem.balanceString, model.buyItem.balanceString) = (model.buyItem.balanceString, model.sellItem.balanceString)
    (model.sellItem.amountString, model.buyItem.amountString) = (model.buyItem.amountString, model.sellItem.amountString)
    didUpdateModel?(model)
  }
  
  func didTapSettings() {
    settingsTapped?()
  }
  
  private func updateEstimations(changePosition: Int) async {
    // check if amount is entered
    if (changePosition == 1 && model.sellItem.swapItem?.amount ?? 0 < 1) ||
        (changePosition == 2 && model.buyItem.swapItem?.amount ?? 0 < 1) {
      model.button.isEnabled = false
      model.button.isActivity = false
      model.button.title = TKLocales.Swap.enterAmount
      await MainActor.run {
        didUpdateModel?(model)
      }
      return
    }
    if await model.sellItem.swapItem!.amount > swapItemsController.getAmountAvailable(symbol: defaultSellItem.symbol) {
      model.button.isEnabled = false
      model.button.isActivity = false
      model.button.title = TKLocales.Swap.insufficientBalance + defaultSellItem.symbol
      await MainActor.run {
        didUpdateModel?(model)
      }
      return
    }
    
    // check if tokens are selected
    guard let sellItem = model.sellItem.swapItem, let buyItem = model.buyItem.swapItem else {
      model.button.isEnabled = false
      model.button.isActivity = false
      model.button.title = TKLocales.Swap.chooseToken
      await MainActor.run {
        didUpdateModel?(model)
      }
      return
    }
    model.button.isEnabled = false
    model.button.isActivity = true
    await MainActor.run {
      didUpdateModel?(model)
    }
    if changePosition == 1 {
      model.estimate = try? await swapItemsController.swapEstimate(offerAddress: sellItem.contractAddress ?? "",
                                                                 askAddress: buyItem.contractAddress ?? "",
                                                                 units: sellItem.amount,
                                                                 slippageTolerance: model.slippage)
      guard let estimate = model.estimate else {
        model.button.isActivity = false
        model.button.isEnabled = false
        await MainActor.run {
          didUpdateModel?(model)
        }
        return
      }
      model.buyItem.swapItem?.amount = BigUInt(estimate.askUnits ?? 0)
      model.buyItem.amountString = swapItemsController.convertAmountToInputString(amount: BigUInt(estimate.askUnits ?? 0),
                                                                                  token: buyItem.token)
    } else {
      model.estimate = try? await swapItemsController.reverseSwapEstimate(offerAddress: sellItem.contractAddress ?? "",
                                                                          askAddress: buyItem.contractAddress ?? "",
                                                                          units: buyItem.amount,
                                                                          slippageTolerance: 0.001)
      guard let estimate = model.estimate else {
        model.button.isActivity = false
        model.button.isEnabled = false
        await MainActor.run {
          didUpdateModel?(model)
        }
        return
      }
      model.sellItem.swapItem?.amount = BigUInt(estimate.offerUnits ?? 0)
      model.sellItem.amountString = swapItemsController.convertAmountToInputString(amount: BigUInt(estimate.offerUnits ?? 0),
                                                                                   token: buyItem.token)
    }
    model.minAskAmount = swapItemsController.convertAmountToInputString(amount: BigUInt(model.estimate?.minAskUnits ?? 0),
                                                                        token: buyItem.token)
    model.liquidityFee = swapItemsController.convertAmountToInputString(amount: BigUInt(model.estimate?.feeUnits ?? 0),
                                                                        token: buyItem.token)
    model.button.isActivity = false
    model.button.isEnabled = true
    model.button.title = TKLocales.Actions.continue_action
    await MainActor.run {
      didUpdateModel?(model)
    }
  }
  
  // MARK: - State
  
  private let swapItemsController: SwapItemsController
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
  private let defaultBuyItem: SwapItem?
  private let defaultSlippage: Float
  init(sellItem: SwapItem,
       buyItem: SwapItem?,
       slippage: Float,
       swapItemsController: SwapItemsController,
       walletsStore: WalletsStore) {
    self.defaultSellItem = sellItem
    self.defaultBuyItem = buyItem
    self.defaultSlippage = slippage
    self.swapItemsController = swapItemsController
    self.walletsStore = walletsStore
  }
}

private extension SwapItemsViewModelImplementation {
  func createModel() -> SwapItemsModel {
    let model = SwapItemsModel(
      assets: nil,
      sellItem: SwapItemsModel.SwapViewItem(
        title: TKLocales.Swap.send,
        swapItem: defaultSellItem,
        amountString: swapItemsController.convertAmountToInputString(amount: defaultSellItem.amount, token: defaultSellItem.token),
        balanceString: ""
      ),
      buyItem: SwapItemsModel.SwapViewItem(
        title: TKLocales.Swap.receive,
        swapItem: defaultBuyItem,
        amountString: defaultBuyItem != nil ? swapItemsController.convertAmountToInputString(amount: defaultBuyItem!.amount,
                                                                                             token: defaultBuyItem!.token) : "",
        balanceString: ""
      ),
      slippage: defaultSlippage,
      button: SwapItemsModel.Button(
        title: TKLocales.Swap.enterAmount,
        isEnabled: false,
        isActivity: false,
        action: { [weak self] in
          guard let self else { return }
          guard let estimate = self.model.estimate, let sellSwapItem = self.model.sellItem.swapItem, let buySwapItem = self.model.buyItem.swapItem else {
            return
          }
          let swapModel = SwapModel(sellItem: sellSwapItem, buyItem: buySwapItem)
          didContinueSwap?(swapModel, estimate)
        }
      )
    )
    Task {
      let amountString = await swapItemsController.convertAmountToInputString(
        amount: swapItemsController.getAmountAvailable(symbol: defaultSellItem.symbol),
        token: defaultSellItem.token
      )
      self.model.sellItem.balanceString = "\(TKLocales.Swap.balance): \(amountString) \(defaultSellItem.symbol)"
      await MainActor.run {
        didUpdateModel?(model)
      }
    }
    return model
  }
  
}

