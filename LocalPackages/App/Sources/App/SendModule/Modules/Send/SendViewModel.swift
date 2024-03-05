import UIKit
import KeeperCore

protocol SendModuleOutput: AnyObject {
  var didTapRecipientItemButton: ((SendTokenModel) -> Void)? { get set }
  var didTapAmountInputButton: ((SendTokenModel) -> Void)? { get set }
  var didTapCommentInputButton: ((SendTokenModel) -> Void)? { get set }
}

protocol SendModuleInput: AnyObject {
  func updateWithSendModel(_ sendModel: SendTokenModel)
}

protocol SendViewModel: AnyObject {
  var didUpdateWalletPickerItems: (([SendPickerCell.Model]) -> Void)? { get set }
  var didUpdateWalletPickerSelectedItemIndex: ((Int) -> Void)? { get set }
  var didUpdateRecipientPickerItems: (([SendPickerCell.Model]) -> Void)? { get set }
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)? { get set }
  var didUpdateRecipient: (([SendPickerCell.Model]) -> Void)? { get set }
  var didUpdateAmount: ((SendAmountInputView.Model) -> Void)? { get set }
  var didUpdateComment: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectFromWalletAtIndex(_ index: Int)
  func didSelectRecipientAtIndex(_ index: Int)
  func didTapRecipientItem()
  func didTapAmountButton()
  func didTapCommentButton()
}

final class SendViewModelImplementation: SendViewModel, SendModuleOutput, SendModuleInput {
  
  // MARK: - SendModuleOutput
  
  var didTapRecipientItemButton: ((SendTokenModel) -> Void)?
  var didTapAmountInputButton: ((SendTokenModel) -> Void)?
  var didTapCommentInputButton: ((SendTokenModel) -> Void)?
  
  // MARK: - SendModuleInput
  
  func updateWithSendModel(_ sendModel: SendTokenModel) {
    sendController.setInputRecipient(sendModel.recipient)
    sendController.setToken(sendModel.token, amount: sendModel.amount)
    sendController.setComment(sendModel.comment)
  }
  
  // MARK: - SendViewModel
  
  var didUpdateWalletPickerItems: (([SendPickerCell.Model]) -> Void)?
  var didUpdateWalletPickerSelectedItemIndex: ((Int) -> Void)?
  var didUpdateRecipientPickerItems: (([SendPickerCell.Model]) -> Void)?
  var didUpdateRecipient: (([SendPickerCell.Model]) -> Void)?
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)?
  var didUpdateAmount: ((SendAmountInputView.Model) -> Void)?
  var didUpdateComment: ((String?) -> Void)?
  
  func viewDidLoad() {
    bindControllerEvents()
    sendController.start()
  }
  
  func didTapRecipientItem() {
    guard let selectedWallet = sendController.selectedWallet else { return }
    let sendTokenModel = SendTokenModel(
      wallet: selectedWallet,
      recipient: sendController.inputRecipient,
      amount: sendController.amount,
      token: sendController.token,
      comment: sendController.comment
    )
    didTapRecipientItemButton?(sendTokenModel)
  }
  
  func didTapAmountButton() {
    guard let selectedWallet = sendController.selectedWallet else { return }
    let sendTokenModel = SendTokenModel(
      wallet: selectedWallet,
      recipient: sendController.inputRecipient,
      amount: sendController.amount,
      token: sendController.token,
      comment: sendController.comment
    )
    self.didTapAmountInputButton?(sendTokenModel)
  }
  
  func didTapCommentButton() {
    guard let selectedWallet = sendController.selectedWallet else { return }
    let sendTokenModel = SendTokenModel(
      wallet: selectedWallet,
      recipient: sendController.inputRecipient,
      amount: sendController.amount,
      token: sendController.token,
      comment: sendController.comment
    )
    self.didTapCommentInputButton?(sendTokenModel)
  }
  
  func didSelectFromWalletAtIndex(_ index: Int) {
    sendController.setWalletSelectedSender(index: index)
  }
  
  func didSelectRecipientAtIndex(_ index: Int) {
    if index == 0 {
      sendController.setInputRecipientSelectedRecipient()
    } else {
      sendController.setWalletSelectedRecipient(index: index)
    }
  }

  // MARK: - Dependencies
  
  private let sendController: SendController
  
  // MARK: - Init
  
  init(sendController: SendController) {
    self.sendController = sendController
  }
}

private extension SendViewModelImplementation {
  func bindControllerEvents() {
    sendController.didUpdateFromWallets = { [weak self] in
      guard let self = self else { return }
      let models = self.sendController.getFromWalletsModels()
      let items = self.mapFromWallets(models: models)
      didUpdateWalletPickerItems?(items)
    }
    
    sendController.didUpdateSelectedFromWallet = { [weak self] index in
      self?.didUpdateWalletPickerSelectedItemIndex?(index)
    }
    
    sendController.didUpdateToWallets = { [weak self] in
      guard let self = self else { return }
      let recipientModel = self.sendController.getInputRecipientModel()
      let walletModels = self.sendController.getToWalletsModels()
      let items = CollectionOfOne(mapRecipient(recipientModel)) + mapToWallets(models: walletModels)
      didUpdateRecipientPickerItems?(items)
    }
    
    sendController.didUpdateInputRecipient = { [weak self] in
      guard let self = self else { return }
      let recipientModel = self.sendController.getInputRecipientModel()
      let walletModels = self.sendController.getToWalletsModels()
      let items = CollectionOfOne(mapRecipient(recipientModel)) + mapToWallets(models: walletModels)
      didUpdateRecipientPickerItems?(items)
    }
    
    sendController.didUpdateIsSendAvailable = { [weak self] isAvailable in
      self?.didUpdateContinueButtonIsEnabled?(isAvailable)
    }
    
    sendController.didUpdateAmount = { [weak self] in
      guard let self = self else { return }
      let amount = self.sendController.getAmountValue()
      self.didUpdateAmount?(SendAmountInputView.Model(amount: amount))
    }
    
    sendController.didUpdateComment = { [weak self] in
      guard let self = self else { return }
      self.didUpdateComment?(self.sendController.getComment())
    }
  }
  
  func mapFromWallets(models: [SendController.SendWalletModel]) -> [SendPickerCell.Model] {
    models.map { model in
      SendPickerCell.Model(
        id: model.id,
        informationModel: SendPickerCell.InformationView.Model(
          topText: "From:".withTextStyle(.body1, color: .Text.secondary, alignment: .left),
          bottomText: model.name.withTextStyle(.body1, color: .Text.primary, alignment: .left)
        ),
        rightView: .amount(
          SendPickerCell.AmountView.Model(
            amount: model.balance.withTextStyle(.body1, color: .Text.primary, alignment: .left),
            isPickEnable: model.isPickerEnabled
          )
        )
      )
    }
  }
  
  func mapToWallets(models: [SendController.SendWalletModel]) -> [SendPickerCell.Model] {
    models.map { model in
      SendPickerCell.Model(
        id: model.id,
        informationModel: SendPickerCell.InformationView.Model(
          topText: "To:".withTextStyle(.body1, color: .Text.secondary, alignment: .left),
          bottomText: model.name.withTextStyle(.body1, color: .Text.primary, alignment: .left)
        ),
        rightView: .amount(
          SendPickerCell.AmountView.Model(
            amount: model.balance.withTextStyle(.body1, color: .Text.primary, alignment: .left),
            isPickEnable: false
          )
        )
      )
    }
  }
  
  func mapRecipient(_ recipient: SendController.SendRecipientModel) -> SendPickerCell.Model {
    let rightView: SendPickerCell.RightView.Model
    if recipient.isEmpty {
      rightView = .empty(SendPickerCell.EmptyAccessoriesView.Model(pasteButtonAction: { [weak self] in
        guard let pasteboardString = UIPasteboard.general.string else { return }
        self?.sendController.setInputRecipient(with: pasteboardString)
      }))
    } else {
      rightView = .none
    }
    
    return SendPickerCell.Model(
      id: UUID().uuidString,
      informationModel: SendPickerCell.InformationView.Model(
        topText: "To:".withTextStyle(.body1, color: .Text.secondary, alignment: .left),
        bottomText: recipient.value.withTextStyle(
          .body1,
          color: recipient.isEmpty ? .Text.secondary : .Text.primary,
          alignment: .left,
          lineBreakMode: .byTruncatingMiddle
        )
      ),
      rightView: rightView
    )
  }
}
