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

  init(token: Token, sendController: SendV3Controller) {
    self.sendToken = token
    self.sendController = sendController
    sendAmountTextFieldFormatter.maximumFractionDigits = token.tokenFractionalDigits
  }

  // MARK: - SendV3ModuleOutput

  var didTapToken: ((SwapField) -> Void)?

  // MARK: - SendV3ModuleInput

  func update(swapField: SwapField, token: Token) {
    switch swapField {
    case .send: sendToken = token
    case .receive: receiveToken = token
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
    let amount = sendController.convertInputStringToAmount(input: unformatted, targetFractionalDigits: sendToken.tokenFractionalDigits)
    Task {
      print(amount)
      let isAmountValid = await sendController.isAmountAvailableToSend(amount: amount.amount, token: sendToken) && !amount.amount.isZero
      await MainActor.run {
        self.isSendAmountValid = isAmountValid
        update()
      }
    }
    self.sendAmount = formatted.count > 0 ? formatted : "0"
    update()
  }

  func didTapMax(isHalf: Bool) {
    if !isHalf {
      didInputAmount(sendBalance)
    } else {
      Task {
        let amount = await sendController.getMaximumAmount(token: sendToken) / 2
        let formatted = sendController.convertAmountToInputString(amount: amount, token: sendToken)
        await MainActor.run {
          self.sendAmount = formatted.count > 0 ? formatted : "0"
          update()
        }
      }
    }
  }

  // MARK: - State

  private var sendToken: Token
  private var sendAmount = "0"
  private var sendBalance = ""
  private var isSendAmountValid = false

  private var receiveToken: Token?
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
    didUpdateModel?(
      SwapView.Model(
        send: createFieldModel(field: .send),
        receive: createFieldModel(field: .receive),
        status: createStatusModel()
      )
    )
  }

  func updateTotalBalance(field: SwapField) {
    if field == .receive, receiveToken == nil { return }
    Task {
      let remaining = await sendController.calculateRemaining(
        token: field == .send ? sendToken : receiveToken!, tokenAmount: 0, showSymbol: false
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
      token: field == .send ? createTokenModel(token: sendToken) :
        (receiveToken != nil) ? createTokenModel(token: receiveToken!) : nil,
      amount: field == .send ? sendAmount : receiveAmount,
      balance: field == .send ? sendBalance : receiveBalance
    )
  }

  func createStatusModel() -> SwapView.Model.Status {
    let sendAmountNotEmpty = sendAmount != "0" && sendAmount.count > 0
    let receiveTokenNotEmpty = receiveToken != nil

    var hint = ""
    if !sendAmountNotEmpty {
      hint = "Enter Amount"
    } else if !isSendAmountValid {
      hint = "Enter Valid Amount"
    } else if !receiveTokenNotEmpty {
      hint = "Choose Token"
    }
    
    return SwapView.Model.Status(
      isValid:  sendAmountNotEmpty && receiveTokenNotEmpty && isSendAmountValid,
      isValidReceiveToken: receiveTokenNotEmpty,
      isValidSendAmount: isSendAmountValid,
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
      let isValidSendAmount: Bool
      let hint: String
    }
    let send: Field
    let receive: Field
    let status: Status
  }
}
