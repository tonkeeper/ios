import Foundation
import KeeperCore
import TKCore
import BigInt

protocol SwapModuleOutput: AnyObject {
  var didTapToken: ((SwapField) -> Void)? { get set }
}

protocol SwapModuleInput: AnyObject {
  func update(swapField: SwapField, token: Token)
}

protocol SwapViewModel: AnyObject {
  var didUpdateModel: ((SwapView.Model) -> Void)? { get set }
  func viewDidLoad()

  func didTapTokenPicker(swapField: SwapField)
  func didInputAmount(_ string: String)
  func didTapMax(isHalf: Bool)
}

final class SwapViewModelImplementation: SwapViewModel, SwapModuleOutput, SwapModuleInput {

  init(swapItem: SwapPair.Item, sendController: SendV3Controller) {
    self.swapPair = SwapPair(send: swapItem, receive: nil)
    self.sendController = sendController
    sendAmountTextFieldFormatter.maximumFractionDigits = swapItem.token.tokenFractionalDigits
  }

  // MARK: - SendV3ModuleOutput

  var didTapToken: ((SwapField) -> Void)?

  // MARK: - SendV3ModuleInput

  func update(swapField: SwapField, token: Token) {
    switch swapField {
    case .send:
      swapPair = SwapPair(send: .init(token: token, amount: swapPair.send.amount), receive: swapPair.receive)
    case .receive:
      swapPair = SwapPair(send: swapPair.send, receive: .init(token: token, amount: swapPair.receive?.amount ?? 0))
    }
    update()
  }

  // MARK: - SwapViewModel

  var didUpdateModel: ((SwapView.Model) -> Void)?
  
  func viewDidLoad() {
    updateTotalBalance(field: .send)
    update()
  }

  func didTapTokenPicker(swapField: SwapField) {
    didTapToken?(swapField)
  }

  func didInputAmount(_ string: String) {
    guard string != sendAmount else { return }
    let unformatted = sendAmountTextFieldFormatter.unformatString(string) ?? ""
    let formatted = sendAmountTextFieldFormatter.formatString(unformatted) ?? ""
    let amount = sendController.convertInputStringToAmount(
      input: unformatted, 
      targetFractionalDigits: swapPair.send.token.tokenFractionalDigits
    )
    sendAmount = formatted.count > 0 ? formatted : "0"
    Task {
      let isAmountValid = await sendController.isAmountAvailableToSend(
        amount: amount.amount,
        token: swapPair.send.token
      ) && !amount.amount.isZero
      await MainActor.run {
        isSendAmountValid = isAmountValid
        swapPair = SwapPair(send: .init(token: swapPair.send.token, amount: amount.amount), receive: swapPair.receive)
        update()
      }
    }
    update()
  }

  func didTapMax(isHalf: Bool) {
    if !isHalf {
      didInputAmount(sendBalance)
    } else {
      Task {
        let amount = await sendController.getMaximumAmount(token: swapPair.send.token) / 2
        let formatted = sendController.convertAmountToInputString(amount: amount, token: swapPair.send.token)
        await MainActor.run {
          self.sendAmount = formatted.count > 0 ? formatted : "0"
          update()
        }
      }
    }
  }

  // MARK: - State

  private var swapPair: SwapPair

  private var sendAmount = "0"
  private var sendBalance = ""
  private var isSendAmountValid = false

  private var receiveAmount = "0"
  private var receiveBalance = ""

  // MARK: - Dependencies
  
  private let imageLoader = ImageLoader()
  private let sendController: SendV3Controller
  
  // MARK: - Formatters
  
  private let sendAmountTextFieldFormatter = SendAmountTextFieldFormatterFactory.make(groupingSeparator: ",")
}

private extension SwapViewModelImplementation {
  func update() {
    didUpdateModel?(SwapView.Model(
      send: createFieldModel(field: .send),
      receive: createFieldModel(field: .receive),
      status: createStatusModel()
    ))
  }

  func updateTotalBalance(field: SwapField) {
    if field == .receive, swapPair.receive?.token == nil { return }
    Task {
      let remaining = await sendController.calculateRemaining(
        token: field == .send ? swapPair.send.token : swapPair.receive!.token,
        tokenAmount: 0,
        showSymbol: false
      )
      await MainActor.run {
        switch remaining {
        case let .remaining(balance):
          if field == .send {
            self.sendBalance = balance
          } else if field == .receive {
            self.receiveBalance = balance
          }
        case .insufficient: return
        }
        update()
      }
    }
  }

  func createFieldModel(field: SwapField) -> SwapView.Model.Field {
    SwapView.Model.Field(
      token: field == .send ? createTokenModel(token: swapPair.send.token) :
        (swapPair.receive != nil) ? createTokenModel(token: swapPair.receive!.token) : nil,
      amount: field == .send ? sendAmount : receiveAmount,
      balance: field == .send ? sendBalance : receiveBalance
    )
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
      isValid: receiveTokenNotEmpty && isSendAmountValid,
      isValidReceiveToken: receiveTokenNotEmpty,
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
      let hint: String
    }
    let send: Field
    let receive: Field
    let status: Status
  }
}
