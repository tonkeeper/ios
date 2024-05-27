import Foundation
import KeeperCore
import TKCore
import BigInt

protocol SwapModuleOutput: AnyObject {
  var didTapToken: ((SwapField, Token?) -> Void)? { get set }
  var didContinueSwap: ((SwapItem, SwapView.Model) -> Void)? { get set }
}

protocol SwapModuleInput: AnyObject {
  func update(swapField: SwapField, token: Token)
}

protocol SwapViewModel: AnyObject {
  var didUpdateModel: ((SwapView.Model) -> Void)? { get set }
  var shoudMakeActive: ((SwapField) -> Void)? { get set }
  var shouldReloadProvider: (() -> Void)? { get set }
  
  func viewDidLoad()

  func swapTokens()
  func didTapTokenPicker(swapField: SwapField)
  func didInputAmount(_ string: String, swapField: SwapField)
  func didTapMax()
  func didTapContinue()
}

final class SwapViewModelImplementation: SwapViewModel, SwapModuleOutput, SwapModuleInput {

  init(swapItem: SwapPair.Item, swapController: SwapController) {
    self.swapPair = SwapPair(send: swapItem, receive: nil)
    self.swapController = swapController
    sendAmountTextFieldFormatter = SendAmountTextFieldFormatterFactory.make(groupingSeparator: swapController.groupSeparatorForFormatting)
    sendAmountTextFieldFormatter.maximumFractionDigits = swapItem.token.tokenFractionalDigits
  }

  // MARK: - SendV3ModuleOutput

  var didTapToken: ((SwapField, Token?) -> Void)?
  var didContinueSwap: ((SwapItem, SwapView.Model) -> Void)?

  // MARK: - SendV3ModuleInput

  func update(swapField: SwapField, token: Token) {
    let firstTimeReceiveChoosen = swapField == .receive && swapPair.receive == nil
    switch swapField {
    case .send:
      swapPair = SwapPair(send: .init(token: token, amount: swapPair.send.amount), receive: swapPair.receive)
    case .receive:
      swapPair = SwapPair(send: swapPair.send, receive: .init(token: token, amount: swapPair.receive?.amount ?? 0))
    }
    didInputAmount(sendAmount, swapField: .send)
    if !firstTimeReceiveChoosen {
      shoudMakeActive?(.send)
    }
    if swapPair.receive != nil {
      shouldReloadProvider?()
    }
  }

  // MARK: - SwapViewModel

  var didUpdateModel: ((SwapView.Model) -> Void)?
  var shoudMakeActive: ((SwapField) -> Void)?
  var shouldReloadProvider: (() -> Void)?
  
  func viewDidLoad() {
    didInputAmount("", swapField: .send)
  }

  func swapTokens() {
    guard let receive = swapPair.receive else { return }
    swapPair = .init(send: receive, receive: swapPair.send)

    let oldSendBalance = sendBalance
    sendBalance = receiveBalance
    receiveBalance = oldSendBalance

    let oldSendAmount = sendAmount
    sendAmount = receiveAmount
    receiveAmount = oldSendAmount

    didInputAmount(sendAmount, swapField: .send)
    shoudMakeActive?(.send)
    shouldReloadProvider?()
  }
  func didTapTokenPicker(swapField: SwapField) {
    didTapToken?(swapField, swapField == .send ? swapPair.receive?.token : swapPair.send.token)
  }

  func didInputAmount(_ string: String, swapField: SwapField) {
    let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""
    let formatted = sendAmountTextFieldFormatter.formatString(unformatted) ?? ""
    sendAmount = formatted.count > 0 ? formatted : "0"
    update()

    Task {
      let amount = swapController.convertInputStringToAmount(
        input: unformatted,
        targetFractionalDigits: swapPair.send.token.tokenFractionalDigits
      )
      let isAmountValid = await swapController.isAmountAvailableToSend(
        amount: amount.amount,
        token: swapPair.send.token
      )
      async let oneTokenAsync = try? swapController.convertOneTokenAmountToCurrency(token: swapPair.send.token)
      async let balanceAsync = updateBalance(field: .send)
      async let receiveDataAsync = updateReceive(with: amount.amount)

      let oneToken = await oneTokenAsync
      let balance = await balanceAsync
      let receiveData = await receiveDataAsync
      
      await MainActor.run {
        oneTokenPrice = oneToken ?? ""
        isSendAmountValid = isAmountValid
        sendBalance = balance
        receiveBalance = receiveData.totalBalance
        swapPair = SwapPair(
          send: .init(token: swapPair.send.token, amount: amount.amount), 
          receive: swapPair.receive != nil ? .init(token: swapPair.receive!.token, amount: receiveData.minimumAmount) : nil // minimum amount is already here, not the maximum
        )
        receiveAmount = receiveData.receiveFormatted
        receiveMiminumAmount = receiveData.minimumFormatted
        update()
      }
    }
  }

  func didTapMax() {
    didInputAmount(sendBalance, swapField: .send)
  }

  func didTapContinue() {
    didContinueSwap?(SwapItem(
      sendToken: swapPair.send.token,
      sendAmount: swapPair.send.amount,
      receiveToken: swapPair.receive!.token,
      receiveAmount: swapPair.receive!.amount
    ), SwapView.Model(
      send: createFieldModel(field: .send),
      receive: createFieldModel(field: .receive),
      status: createStatusModel(),
      oneTokenPrice: oneTokenPrice,
      swapDetails: createSwapDetails()
    ))
  }

  // MARK: - State

  private var swapPair: SwapPair
  private var priceChangeLimit: Double = 0.01 // 1%

  private var sendAmount = "0"
  private var sendBalance = ""
  private var isSendAmountValid = false
  private var oneTokenPrice = ""

  private var receiveAmount = "0"
  private var receiveBalance = ""
  private var receiveMiminumAmount = "0"

  // MARK: - Dependencies
  
  private let imageLoader = ImageLoader()
  private let swapController: SwapController
  
  // MARK: - Formatters
  
  private let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter
}

private extension SwapViewModelImplementation {
  func update() {
    didUpdateModel?(SwapView.Model(
      send: createFieldModel(field: .send),
      receive: createFieldModel(field: .receive),
      status: createStatusModel(),
      oneTokenPrice: oneTokenPrice,
      swapDetails: createSwapDetails()
    ))
  }

  func updateReceive(with sendAmount: BigUInt) async -> (
    receiveAmount: BigUInt,
    minimumAmount: BigUInt,
    receiveFormatted: String,
    minimumFormatted: String,
    totalBalance: String) {

    guard let receiveToken = swapPair.receive?.token else { return (0, 0, "0", "0", "") }
    let totalAmount = await swapController.getMaximumAmount(token: receiveToken)
    let formattedTotal = swapController.convertAmountToInputString(amount: totalAmount, token: receiveToken)
    let receiveAmounts = (try? await swapController.calculateReceiveRate(
      sendToken: swapPair.send.token,
      amount: sendAmount,
      receiveToken: receiveToken,
      priceChangeLimit: priceChangeLimit
    ))
    let receiveAmount = receiveAmounts?.expected ?? 0 // not used right now –> only minumum is intresting for swap
    let minimumAmount = receiveAmounts?.minimum ?? 0
    let receiveAmountFormatted = swapController.convertAmountToInputString(amount: receiveAmount, token: receiveToken)
    let minimumAmountFormatted = swapController.convertAmountToInputString(amount: minimumAmount, token: receiveToken)
    return (receiveAmount, minimumAmount, receiveAmountFormatted, minimumAmountFormatted, formattedTotal)
  }

  func updateBalance(field: SwapField) async -> String {
    if field == .receive, swapPair.receive?.token == nil { return "" }
    let token = field == .send ? swapPair.send.token : swapPair.receive!.token
    let amount = await swapController.getMaximumAmount(token: token)
    return swapController.convertAmountToInputString(amount: amount, token: token)
  }

  func createFieldModel(field: SwapField) -> SwapView.Model.Field {
    SwapView.Model.Field(
      token: field == .send ? createTokenModel(token: swapPair.send.token) :
        (swapPair.receive != nil) ? createTokenModel(token: swapPair.receive!.token) : nil,
      amount: field == .send ? sendAmount : receiveAmount,
      balance: field == .send ? "Balance: \(sendBalance)" : receiveBalance.isEmpty ? "" : "Balance: \(receiveBalance)"
    )
  }

  func createSwapDetails() -> [SwapDetailsView.Item] {
    let sendTokenSymbol = swapPair.send.token.symbol ?? ""
    let receiveTokenSymbol = swapPair.receive?.token.symbol ?? ""
    return [
      SwapDetailsView.Item(title: "Price impact", hint: nil, value: "\(priceChangeLimit * 100)%"),
      SwapDetailsView.Item(title: "Minimum received", hint: nil, value: "\(receiveMiminumAmount) \(receiveTokenSymbol)"),
      SwapDetailsView.Item(title: "Blockchain fee", hint: nil, value: "0.08-0.3 TON"),
      SwapDetailsView.Item(title: "Route", hint: nil, value: "\(sendTokenSymbol) » \(receiveTokenSymbol)"),
      SwapDetailsView.Item(title: "Provider", hint: nil, value: "STON.fi")
    ]
  }

  func createStatusModel() -> SwapView.Model.Status {
    let receiveTokenNotEmpty = swapPair.receive?.token != nil

    var hint = ""
    if swapPair.send.amount == 0 {
      hint = "Enter Amount"
    } else if !isSendAmountValid {
      hint = "Enter Valid Amount"
    } else if !receiveTokenNotEmpty {
      hint = "Choose Receive Token"
    }
    return SwapView.Model.Status(
      isValid: receiveTokenNotEmpty && isSendAmountValid && swapPair.send.amount > 0,
      isValidReceiveToken: receiveTokenNotEmpty,
      isSendAmountValid: isSendAmountValid,
      hint: hint
    )
  }

  // TODO: - duplicate SendV3ViewModelImplementation
  func createTokenModel(token: Token) -> SwapInputTokenView.Token {
    let title: String
    let image: SendV3View.Model.Amount.Token.Image
    switch token {
    case .ton:
      title = "TON"
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .jetton(let item):
      title = item.jettonInfo.symbol ?? ""
      image = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
        self?.imageLoader.loadImage(url: item.jettonInfo.imageURL, imageView: imageView, size: size, cornerRadius: cornerRadius)
      }))
    }
    return SwapInputTokenView.Token(
      name: title,
      image: image
    )
  }
}

extension SwapView {
  struct Model {
    struct Field {
      let token: SwapInputTokenView.Token?
      let amount: String
      let balance: String
    }
    struct Status {
      let isValid: Bool
      let isValidReceiveToken: Bool
      let isSendAmountValid: Bool
      let hint: String
    }
    let send: Field
    let receive: Field
    let status: Status
    let oneTokenPrice: String
    let swapDetails: [SwapDetailsView.Item]
  }
}
