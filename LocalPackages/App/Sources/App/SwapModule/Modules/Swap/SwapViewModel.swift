import UIKit
import TKCore
import KeeperCore
import BigInt
import TonSwift

struct SwapToken {
  enum Icon {
    case image(UIImage)
    case asyncImage(URL?)
  }
  
  struct Balance {
    var amount: BigUInt
  }
  
  var icon: Icon
  var asset: SwapAsset
  var balance: Balance
  var inputAmount: String
}

extension SwapToken {
  static let tonStub = SwapToken(
    icon: .image(.TKCore.Icons.Size44.tonLogo),
    asset: SwapAsset(
      kind: .ton,
      contractAddress: try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
      symbol: TonInfo.symbol,
      displayName: TonInfo.name,
      fractionDigits: TonInfo.fractionDigits,
      isWhitelisted: true
    ),
    balance: SwapToken.Balance(
      amount: .testBalanceAmount // 100,000.01
    ),
    inputAmount: "0"
  )
  
  static let usdtStub = SwapToken(
    icon: .asyncImage(URL(string: "https://asset.ston.fi/img/EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs")!),
    asset: SwapAsset(
      kind: .jetton,
      contractAddress: try! Address.parse("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"),
      symbol: "USD₮",
      displayName: "USD₮",
      fractionDigits: 6,
      isWhitelisted: true
    ),
    balance: SwapToken.Balance(
      amount: .testBalanceAmount // 100,000.01
    ),
    inputAmount: "0"
  )
}

private extension BigUInt {
  static let testBalanceAmount = BigUInt(stringLiteral: "100000010000000")
}

struct SwapModel {
  struct SwapButton {
    let action: (() -> Void)?
  }
  
  let title: String
  let swapButton: SwapButton
}

struct SwapStateModel {
  let sendTextFieldState: PlainTextField.TextFieldState
  let actionButton: SwapActionButtonModel
}

struct SwapActionButtonModel {
  let title: String
  let backgroundColor: UIColor
  let backgroundColorHighlighted: UIColor
  let isEnabled: Bool
  let isActivity: Bool
  let action: (() -> Void)?
}

enum SwapInput {
  case send
  case recieve
  
  var opposite: SwapInput {
    switch self {
    case .send:
      return .recieve
    case .recieve:
      return .send
    }
  }
}

struct SwapOperationItem {
  var sendToken: SwapToken?
  var recieveToken: SwapToken?
}

protocol SwapModuleOutput: AnyObject {
  var didTapSwapSettings: (() -> Void)? { get set }
  var didTapTokenButton: ((Address?, SwapInput) -> Void)? { get set }
  var didTapBuyTon: (() -> Void)? { get set }
  var didTapContinue: ((SwapConfirmationItem) -> Void)? { get set }
}

protocol SwapModuleInput: AnyObject {
  func didChooseToken(_ swapAsset: SwapAsset, forInput input: SwapInput)
}

protocol SwapViewModel: AnyObject {
  var didUpdateModel: ((SwapModel) -> Void)? { get set }
  var didUpdateStateModel: ((SwapStateModel) -> Void)? { get set }
  var didUpdateDetailsModel: ((SwapDetailsContainerView.Model?) -> Void)? { get set }
  var didUpdateIsRefreshing: ((Bool) -> Void)? { get set }
  var didUpdateAmountSend: ((String) -> Void)? { get set }
  var didUpdateAmountRecieve: ((String) -> Void)? { get set }
  var didUpdateSendTokenBalance: ((String) -> Void)? { get set }
  var didUpdateRecieveTokenBalance: ((String) -> Void)? { get set }
  var didUpdateSwapSendContainer: ((SwapSendContainerView.Model) -> Void)? { get set }
  var didUpdateSwapRecieveContainer: ((SwapRecieveContainerView.Model) -> Void)? { get set }
  var amountInpuTextFieldFormatter: BuySellAmountTextFieldFormatter { get }
  
  func viewDidLoad()
  func didInputAmountSend(_ string: String)
  func didInputAmountRecieve(_ string: String)
  func didTapMaxButton()
  func didTapSwapButton()
  func didTapSwapSettingsButton()
}

final class SwapViewModelImplementation: SwapViewModel, SwapModuleOutput, SwapModuleInput {
  
  enum SwapState: Equatable {
    case enterAmount
    case chooseToken
    case insufficientBalanceTon
    case insufficientBalance(tokenSymbol: String)
    case continueSwap
    case simulationFail
  }
  
  enum SwapSimulationResult: Equatable {
    case empty
    case success(SwapSimulationModel)
    case fail
    case cancel
    
    var isSimulationFailed: Bool {
      self == .fail
    }
    
    var swapSimulationModel: SwapSimulationModel? {
      if case let .success(swapSimulationModel) = self {
        return swapSimulationModel
      }
      return nil
    }
  }
  
  enum Remaining: Equatable {
    case remaining(String)
    case insufficient
    
    var value: String {
      switch self {
      case .remaining(let value):
        return value
      case .insufficient:
        return "0"
      }
    }
  }
  
  // MARK: - SwapModuleOutput
  
  var didTapSwapSettings: (() -> Void)?
  var didTapTokenButton: ((Address?, SwapInput) -> Void)?
  var didTapBuyTon: (() -> Void)?
  var didTapContinue: ((SwapConfirmationItem) -> Void)?
  
  // MARK: - SwapModuleInput
  
  func didChooseToken(_ swapAsset: SwapAsset, forInput input: SwapInput) {
    let oldAsset = token(atInput: input)?.asset
    let newToken = swapItemMapper.mapSwapAsset(swapAsset)
    let oppositeToken = token(atInput: input.opposite)
    let isOppositeAssetSame = newToken.asset == oppositeToken?.asset
    
    if swapAsset != oldAsset {
      isLastSimulationFailed = false
      currentSwapSimulationModel = nil
      clearInput(input)
      
      if input == lastInput {
        clearInput(input.opposite)
      }
    }
    
    setToken(newToken, forInput: input)
    
    Task {
      let tokensHasPair = await swapController.isPairExistsForAssets(newToken.asset, oppositeToken?.asset)
      let shouldRemoveOppositeToken = !tokensHasPair || isOppositeAssetSame
      
      await MainActor.run {
        if shouldRemoveOppositeToken {
          setToken(nil, forInput: input.opposite)
          clearInput(input.opposite)
          lastInput = input
        }
        
        update()
        updateSendBalance()
        updateRecieveBalance()
        
        let swapSimulationDirection = swapSimulationDirection(forLastInput: lastInput)
        simulateSwap(swapSimulationDirection)
      }
    }
  }
  
  // MARK: - SwapViewModel
  
  var didUpdateModel: ((SwapModel) -> Void)?
  var didUpdateStateModel: ((SwapStateModel) -> Void)?
  var didUpdateDetailsModel: ((SwapDetailsContainerView.Model?) -> Void)?
  var didUpdateIsRefreshing: ((Bool) -> Void)?
  var didUpdateAmountSend: ((String) -> Void)?
  var didUpdateAmountRecieve: ((String) -> Void)?
  var didUpdateSendTokenBalance: ((String) -> Void)?
  var didUpdateRecieveTokenBalance: ((String) -> Void)?
  var didUpdateSwapSendContainer: ((SwapSendContainerView.Model) -> Void)?
  var didUpdateSwapRecieveContainer: ((SwapRecieveContainerView.Model) -> Void)?
  
  func viewDidLoad() {
    update()
    updateSwapState()
    
    didTapContinue?(SwapConfirmationItem.testData)

    Task {
      await swapController.start()
      guard let initialSwapAsset = await swapController.getInitalSwapAsset() else { return }
      
      await MainActor.run {
        didChooseToken(initialSwapAsset, forInput: .send)
        
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          self.swapOperationItem.sendToken?.balance.amount = .testBalanceAmount
          self.updateSendBalance()
        }
        #endif
      }
    }
  }
  
  func didInputAmountSend(_ string: String) {
    amountSend = string
    lastInput = .send
    
    if string == "0" {
      clearInput(.recieve)
    }
    
    updateSendBalance()
    
    simulateSwap(.direct)
  }
  
  func didInputAmountRecieve(_ string: String) {
    amountRecieve = string
    lastInput = .recieve
    
    if string == "0" {
      clearInput(.send)
    }
    
    simulateSwap(.reverse)
  }
  
  func didTapMaxButton() {
    guard let sendToken = swapOperationItem.sendToken else { return }
    
    lastInput = .send
    
    let balanceAmountSend = swapController.convertAmountToString(
      amount: sendToken.balance.amount,
      fractionDigits: sendToken.asset.fractionDigits
    )
    
    let unformattedAmountSend = amountInpuTextFieldFormatter.unformatString(balanceAmountSend) ?? "0"
    let formattedAmountSend = amountInpuTextFieldFormatter.formatString(unformattedAmountSend) ?? "0"
    
    updateInputAmount(formattedAmountSend, forInput: .send)
    didInputAmountSend(formattedAmountSend)
  }
  
  func didTapSwapButton() {
    let sendToken = swapOperationItem.sendToken
    swapOperationItem.sendToken = swapOperationItem.recieveToken
    swapOperationItem.recieveToken = sendToken
    
    swap(&amountSend, &amountRecieve)
    
    lastInput = lastInput.opposite
    updateInputAmount(amountSend, forInput: .send)
    updateInputAmount(amountRecieve, forInput: .recieve)
    
    isLastSimulationFailed = false
    currentSwapSimulationModel = nil
    
    update()
    updateSendBalance()
    updateRecieveBalance()
    
    let swapSimulationDirection = swapSimulationDirection(forLastInput: lastInput)
    simulateSwap(swapSimulationDirection)
  }
  
  func didTapSwapSettingsButton() {
    didTapSwapSettings?()
  }
  
  // MARK: - State
  
  private var amountSend = "0" {
    didSet {
      swapOperationItem.sendToken?.inputAmount = amountSend
    }
  }
  
  private var amountRecieve = "0" {
    didSet {
      swapOperationItem.recieveToken?.inputAmount = amountRecieve
    }
  }
  
  private var tokenSendBalanceRemaining = Remaining.remaining("0")
  private var tokenRecieveBalance = "0"
  private var lastInput = SwapInput.send
  private var isLastSimulationFailed = false
  
  private var swapSimulationDebounceTimer: Timer?
  private var swapSimulationAutoRefreshTimer: Timer?
  
  private var currentSwapSimulationModel: SwapSimulationModel? {
    didSet {
      didUpdateCurrentSwapSimulationModel()
    }
  }
  
  private var swapState = SwapState.enterAmount {
    didSet {
      guard swapState != oldValue && !isResolving else { return }
      updateSwapState()
    }
  }
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      updateSwapState()
    }
  }
  
  private var isRefreshing = false {
    didSet {
      guard isRefreshing != oldValue else { return }
      didUpdateIsRefreshing?(isRefreshing)
    }
  }
  
  private var isContinueEnable: Bool {
    true
  }
  
  // MARK: - Mapper
  
  private let swapItemMapper = SwapItemMaper()
  
  // MARK: - Formatter
  
  let amountInpuTextFieldFormatter: BuySellAmountTextFieldFormatter = .makeAmountFormatter()
  
  // MARK: - Dependencies
  
  private let swapController: SwapController
  private var swapOperationItem: SwapOperationItem
  
  // MARK: - Init
  
  init(swapController: SwapController, swapOperationItem: SwapOperationItem) {
    self.swapController = swapController
    self.swapOperationItem = swapOperationItem
    self.amountInpuTextFieldFormatter.maximumFractionDigits = TonInfo.fractionDigits // TODO: Change depends on assets fractionLenght
  }
  
  deinit {
    swapSimulationDebounceTimer?.invalidate()
    swapSimulationAutoRefreshTimer?.invalidate()
    swapSimulationDebounceTimer = nil
    swapSimulationAutoRefreshTimer = nil
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension SwapViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
    
    let swapSendContainerModel = createSwapSendContainerModel()
    let swapRecieveContainerModel = createSwapRecieveContainerModel()
    
    didUpdateSwapSendContainer?(swapSendContainerModel)
    didUpdateSwapRecieveContainer?(swapRecieveContainerModel)
  }
  
  func createModel() -> SwapModel {
    SwapModel(
      title: "Swap",
      swapButton: SwapModel.SwapButton(
        action: { [weak self] in
          self?.didTapSwapButton()
        }
      )
    )
  }
  
  func createSwapSendContainerModel() -> SwapSendContainerView.Model {
    var isInputEnabled = false
    var balanceTitle: String?
    var maxButton: SwapInputContainerView.Model.HeaderButton?
    
    if swapOperationItem.sendToken != nil {
      isInputEnabled = true
      balanceTitle = createBalanceTitle(balance: tokenSendBalanceRemaining.value)
      maxButton = SwapInputContainerView.Model.HeaderButton(
        title: "MAX",
        action: { [weak self] in
          self?.didTapMaxButton()
        }
      )
    }
    
    return SwapSendContainerView.Model(
      inputContainerModel: SwapInputContainerView.Model(
        headerTitle: "Send",
        balanceTitle: balanceTitle,
        maxButton: maxButton,
        tokenButton: swapItemMapper.mapTokenButton(
          buttonToken: swapOperationItem.sendToken,
          action: { [weak self] in
            self?.didTapTokenButton?(nil, .send)
          }
        ),
        textField: SwapInputContainerView.Model.TextField(
          isEnabled: isInputEnabled
        )
      )
    )
  }
  
  func createSwapRecieveContainerModel() -> SwapRecieveContainerView.Model {
    var isInputEnabled = false
    var balanceTitle: String?
    
    if swapOperationItem.recieveToken != nil {
      isInputEnabled = true
      balanceTitle = createBalanceTitle(balance: tokenRecieveBalance)
    }
    
    return SwapRecieveContainerView.Model(
      inputContainerModel: SwapInputContainerView.Model(
        headerTitle: "Recieve",
        balanceTitle: balanceTitle,
        maxButton: nil,
        tokenButton: swapItemMapper.mapTokenButton(
          buttonToken: swapOperationItem.recieveToken,
          action: { [weak self] in
            let addressToPair = self?.swapOperationItem.sendToken?.asset.contractAddress
            self?.didTapTokenButton?(addressToPair, .recieve)
          }
        ),
        textField: SwapInputContainerView.Model.TextField(
          isEnabled: isInputEnabled
        )
      )
    )
  }
  
  func updateInputAmount(_ amount: String, forInput input: SwapInput) {
    switch input {
    case .send:
      amountSend = amount
      didUpdateAmountSend?(amount)
    case .recieve:
      amountRecieve = amount
      didUpdateAmountRecieve?(amount)
    }
  }
  
  func updateSendBalance() {
    guard let sendToken = swapOperationItem.sendToken else {
      tokenSendBalanceRemaining = .insufficient
      return
    }
    
    let fractionDigits = sendToken.asset.fractionDigits
    
    let unformatted = amountInpuTextFieldFormatter.unformatString(amountSend) ?? ""
    let inputAmount = swapController.convertStringToAmount(string: unformatted, targetFractionalDigits: fractionDigits)
    
    if inputAmount.value <= sendToken.balance.amount {
      let remainingBalanceAmount = sendToken.balance.amount - inputAmount.value
      let remainingBalanceString = swapController.convertAmountToString(amount: remainingBalanceAmount, fractionDigits: fractionDigits)
      tokenSendBalanceRemaining = .remaining(remainingBalanceString)
    } else {
      tokenSendBalanceRemaining = .insufficient
    }
    
    let balanceTitle = createBalanceTitle(balance: tokenSendBalanceRemaining.value)
    didUpdateSendTokenBalance?(balanceTitle)
  }
  
  func updateRecieveBalance() {
    guard let recieveToken = swapOperationItem.recieveToken else {
      tokenRecieveBalance = "0"
      return
    }
    
    let fractionDigits = recieveToken.asset.fractionDigits
    
    let balanceString = swapController.convertAmountToString(amount: recieveToken.balance.amount, fractionDigits: fractionDigits)
    let balanceTitle = createBalanceTitle(balance: balanceString)
    tokenRecieveBalance = balanceString
    didUpdateRecieveTokenBalance?(balanceTitle)
  }
  
  func createBalanceTitle(balance: String) -> String {
    "Balance: \(balance)"
  }
  
  func updateSwapState() {
    let stateModel = createSwapStateModel()
    didUpdateStateModel?(stateModel)
  }
  
  func createSwapStateModel() -> SwapStateModel {
    let textFieldState: PlainTextField.TextFieldState
    switch swapState {
    case .insufficientBalance:
      textFieldState = .error
    default:
      textFieldState = .active
    }
    
    return SwapStateModel(
      sendTextFieldState: textFieldState,
      actionButton: createActionButton(forState: swapState)
    )
  }
  
  func recalculateSwapState() {
    let hasSendToken = swapOperationItem.sendToken != nil
    let hasRecieveToken = swapOperationItem.recieveToken != nil
    
    let inputsAreNotEmpty = amountSend != "0" && amountSend != "" && amountRecieve != "0" && amountRecieve != ""
    let hasSwapSimulationModel = currentSwapSimulationModel != nil
    let canContinueSwap = inputsAreNotEmpty && hasSwapSimulationModel && tokenSendBalanceRemaining != .insufficient
    
    var swapState: SwapState
    switch (amountSend, amountRecieve, hasSendToken, hasRecieveToken) {
    case ("0", "0", true, true), ("0", _, true, false):
      swapState = .enterAmount
    case (_, "0", false, true):
      swapState = .chooseToken
    case (_, _, true, _) where tokenSendBalanceRemaining == .insufficient:
      swapState = swapStateForInsufficient(sendTokenSymbol: swapOperationItem.sendToken?.asset.symbol)
    case (_, _, true, false), (_, _, false, true):
      swapState = .chooseToken
    case (_, _, true, true) where canContinueSwap:
      swapState = .continueSwap
    default:
      swapState = .enterAmount
    }
    
    if isLastSimulationFailed {
      swapState = .simulationFail
    }
    
    self.swapState = swapState
  }
  
  func swapStateForInsufficient(sendTokenSymbol: String?) -> SwapState {
    if sendTokenSymbol?.uppercased() == TonInfo.symbol {
      return .insufficientBalanceTon
    } else {
      return .insufficientBalance(tokenSymbol: sendTokenSymbol ?? "")
    }
  }
  
  func createActionButton(forState swapState: SwapState) -> SwapActionButtonModel {
    switch swapState {
    case .enterAmount:
      return createEnterAmountButton()
    case .chooseToken:
      return createChoseTokenButton()
    case .insufficientBalanceTon:
      return createInsufficientBalanceTonButton()
    case .insufficientBalance:
      return createInsufficientBalanceButton()
    case .continueSwap:
      return createContinueButton()
    case .simulationFail:
      return createSimulationFailButton()
    }
  }
  
  func createEnterAmountButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Enter Amount",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isResolving,
      isActivity: isResolving,
      action: nil
    )
  }
  
  func createChoseTokenButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Choose Token",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isResolving,
      isActivity: isResolving,
      action: nil
    )
  }
  
  func createInsufficientBalanceTonButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Insufficient Balance. Buy TON",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: true,
      isActivity:isResolving && currentSwapSimulationModel == nil,
      action: { [weak self] in
        self?.didTapBuyTon?()
      }
    )
  }
  
  func createInsufficientBalanceButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Insufficient \(swapOperationItem.sendToken?.asset.symbol ?? "") balance",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: true,
      isActivity: isResolving && currentSwapSimulationModel == nil,
      action: nil
    )
  }
  
  func createContinueButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Continue",
      backgroundColor: .Button.primaryBackground,
      backgroundColorHighlighted: .Button.primaryBackgroundHighlighted,
      isEnabled: !isResolving && isContinueEnable,
      isActivity: isResolving,
      action: { [weak self] in
        self?.handleContinueButtonTap()
      }
    )
  }
  
  func createSimulationFailButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Simulation fail",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: true,
      isActivity: false,
      action: nil
    )
  }
  
  func handleContinueButtonTap() {
    guard let simulationModel = currentSwapSimulationModel, let token = swapOperationItem.recieveToken else { return }
    let swapOperationItem = self.swapOperationItem
    isResolving = true
    Task {
      let unformatted = amountInpuTextFieldFormatter.unformatString(token.inputAmount) ?? "0"
      let amount = swapController.convertStringToAmount(string: unformatted, targetFractionalDigits: token.asset.fractionDigits)
      let convertedFiatAmount = await swapController.convertAssetAmountToFiat(token.asset, amount: amount.value)
      await MainActor.run {
        let swapConfirmationItem = SwapConfirmationItem(
          convertedFiatAmount: convertedFiatAmount,
          operationItem: swapOperationItem,
          simulationModel: simulationModel
        )
        didTapContinue?(swapConfirmationItem)
        isResolving = false
      }
    }
  }
  
  func token(atInput input: SwapInput) -> SwapToken? {
    switch input {
    case .send:
      return swapOperationItem.sendToken
    case .recieve:
      return swapOperationItem.recieveToken
    }
  }
  
  func setToken(_ token: SwapToken?, forInput input: SwapInput) {
    switch input {
    case .send:
      swapOperationItem.sendToken = token
    case .recieve:
      swapOperationItem.recieveToken = token
    }
  }
  
  func clearAllInputs() {
    clearInput(.send)
    clearInput(.recieve)
  }
  
  func clearInput(_ input: SwapInput) {
    updateInputAmount("0", forInput: input)
  }
  
  func swapSimulationDirection(forLastInput input: SwapInput) -> SwapSimulationDirection {
    switch input {
    case .send:
      return .direct
    case .recieve:
      return .reverse
    }
  }
  
  func simulateSwap(_ direction: SwapSimulationDirection,
                    isResolvingEnabled: Bool = true,
                    debounceDuration: TimeInterval = 0.4,
                    completion: (() -> Void)? = nil) {
    recalculateSwapState()
    isResolving = isNeedStartResolving() && isResolvingEnabled
    swapSimulationDebounceTimer?.invalidate()
    swapSimulationDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDuration, repeats: false) { [weak self] _ in
      self?.swapSimulationAutoRefreshTimer?.invalidate()
      self?.startSwapSimulation(direction: direction, completion: { result in
        self?.didCompleteSwapSimulation(withResult: result)
        self?.updateSendBalance()
        self?.recalculateSwapState()
        self?.isResolving = false
        completion?()
      })
    }
  }
  
  func isNeedStartResolving() -> Bool {
    return swapOperationItem.sendToken != nil
    && swapOperationItem.recieveToken != nil
    && (amountSend != "0" || amountRecieve != "0")
  }
  
  func startSwapSimulation(direction: SwapSimulationDirection, completion: @escaping (SwapSimulationResult) -> Void) {
    guard let sendAsset = swapOperationItem.sendToken?.asset,
          let recieveAsset = swapOperationItem.recieveToken?.asset
    else {
      completion(.empty)
      return
    }
    
    let input: SwapInput
    let inputAmount: String
    let inputAsset: SwapAsset
    
    switch direction {
    case .direct:
      input = .send
      inputAmount = amountSend
      inputAsset = sendAsset
    case .reverse:
      input = .recieve
      inputAmount = amountRecieve
      inputAsset = recieveAsset
    }
    
    let inputUnformatted = amountInpuTextFieldFormatter.unformatString(inputAmount) ?? ""
    let amount = swapController.convertStringToAmount(string: inputUnformatted, targetFractionalDigits: inputAsset.fractionDigits)
    
    guard amount.value != .zero else {
      isLastSimulationFailed = false
      clearInput(input.opposite)
      completion(.empty)
      return
    }
    
    Task {
      do {
        let swapSimulationModel = try await swapController.simulateSwap(
          direction: direction,
          amount: amount.value,
          sendAsset: sendAsset,
          recieveAsset: recieveAsset
        )
        await MainActor.run {
          guard sendAsset == swapOperationItem.sendToken?.asset && recieveAsset == swapOperationItem.recieveToken?.asset else { return }
          let outputAmount = swapSimulationModel.outputAmount(for: direction)
          updateInputAmount(outputAmount, forInput: input.opposite)
          completion(.success(swapSimulationModel))
        }
      }
      catch is CancellationError, URLError.cancelled {
        await MainActor.run {
          completion(.cancel)
        }
      } catch {
        await MainActor.run {
          print(error)
          clearInput(input.opposite)
          completion(.fail)
        }
      }
    }
  }
  
  func didCompleteSwapSimulation(withResult swapSimulationResult: SwapSimulationResult) {
    isLastSimulationFailed = swapSimulationResult.isSimulationFailed
    guard swapSimulationResult != .cancel else { return }
    currentSwapSimulationModel = swapSimulationResult.swapSimulationModel
  }
  
  func didUpdateCurrentSwapSimulationModel() {
    isRefreshing = false
    if currentSwapSimulationModel != nil {
      startSwapSimulationAutoRefresh()
    } else {
      stopSwapSimulationAutoRefresh()
    }
    
    updateDetailsModel()
  }
  
  func startSwapSimulationAutoRefresh() {
    swapSimulationAutoRefreshTimer?.invalidate()
    swapSimulationAutoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
      guard let lastInput = self?.lastInput, let direction = self?.swapSimulationDirection(forLastInput: lastInput) else { return }
      self?.isRefreshing = true
      self?.simulateSwap(direction, isResolvingEnabled: false, debounceDuration: 1.0) {
        self?.isRefreshing = false
      }
    }
  }
  
  func stopSwapSimulationAutoRefresh() {
    swapSimulationAutoRefreshTimer?.invalidate()
    swapSimulationAutoRefreshTimer = nil
  }
  
  func updateDetailsModel() {
    let detailsModel = createDetailsModel(from: currentSwapSimulationModel)
    didUpdateDetailsModel?(detailsModel)
  }
  
  func createDetailsModel(from swapSimulationModel: SwapSimulationModel?) -> SwapDetailsContainerView.Model? {
    guard let swapSimulationModel else { return nil }
    return SwapDetailsContainerView.Model(
      swapRate: swapItemMapper.mapSwapSimulationRate(
        swapRate: swapSimulationModel.swapRate,
        swapRoute: swapSimulationModel.info.route
      ),
      infoContainer: swapItemMapper.mapSwapSimulationInfo(swapSimulationModel.info)
    )
  }
}

private extension BuySellAmountTextFieldFormatter {
  static func makeAmountFormatter() -> BuySellAmountTextFieldFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.groupingSeparator = " "
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    return BuySellAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
  }
}
