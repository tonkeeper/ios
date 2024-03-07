import UIKit
import KeeperCore
import TKCore
import TKUIKit

protocol SendModuleOutput: AnyObject {
  var didTapRecipientItemButton: ((SendModel) -> Void)? { get set }
  var didTapAmountInputButton: ((SendModel) -> Void)? { get set }
  var didTapCommentInputButton: ((SendModel) -> Void)? { get set }
  var didContinueSend: ((SendModel) -> Void)? { get set }
}

protocol SendModuleInput: AnyObject {
  func updateWithSendModel(_ sendModel: SendModel)
}

protocol SendViewModel: AnyObject {
  var didUpdateWalletPickerItems: (([SendPickerCell.Model]) -> Void)? { get set }
  var didUpdateWalletPickerSelectedItemIndex: ((Int) -> Void)? { get set }
  var didUpdateRecipientPickerItems: (([SendPickerCell.Model]) -> Void)? { get set }
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)? { get set }
  var didUpdateRecipient: (([SendPickerCell.Model]) -> Void)? { get set }
  var didUpdateComment: ((String?) -> Void)? { get set }
  var didUpdateSendItem: ((SendItemViewModel) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectFromWalletAtIndex(_ index: Int)
  func didSelectRecipientAtIndex(_ index: Int)
  func didTapRecipientItem()
  func didTapAmountButton()
  func didTapCommentButton()
  func didTapContinueButton()
}

enum SendItemViewModel {
  case token(value: String)
  case nft(nftModel: NFTView.Model)
}

final class SendViewModelImplementation: SendViewModel, SendModuleOutput, SendModuleInput {
  
  // MARK: - SendModuleOutput
  
  var didTapRecipientItemButton: ((SendModel) -> Void)?
  var didTapAmountInputButton: ((SendModel) -> Void)?
  var didTapCommentInputButton: ((SendModel) -> Void)?
  var didContinueSend: ((SendModel) -> Void)?
  
  // MARK: - SendModuleInput
  
  func updateWithSendModel(_ sendModel: SendModel) {
    sendController.setInputRecipient(sendModel.recipient)
    sendController.setSendItem(sendModel.sendItem)
    sendController.setComment(sendModel.comment)
    if sendController.isSendAvailable {
      didContinueSend?(sendModel)
    }
  }
  
  // MARK: - SendViewModel
  
  var didUpdateWalletPickerItems: (([SendPickerCell.Model]) -> Void)?
  var didUpdateWalletPickerSelectedItemIndex: ((Int) -> Void)?
  var didUpdateRecipientPickerItems: (([SendPickerCell.Model]) -> Void)?
  var didUpdateRecipient: (([SendPickerCell.Model]) -> Void)?
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)?
  var didUpdateComment: ((String?) -> Void)?
  var didUpdateSendItem: ((SendItemViewModel) -> Void)?
  
  func viewDidLoad() {
    bindControllerEvents()
    sendController.start()
  }
  
  func didTapRecipientItem() {
    let sendTokenModel = SendModel(
      wallet: sendController.selectedFromWallet,
      recipient: sendController.inputRecipient,
      sendItem: sendController.sendItem,
      comment: sendController.comment
    )
    didTapRecipientItemButton?(sendTokenModel)
  }
  
  func didTapAmountButton() {
    let sendTokenModel = SendModel(
      wallet: sendController.selectedFromWallet,
      recipient: sendController.inputRecipient,
      sendItem: sendController.sendItem,
      comment: sendController.comment
    )
    self.didTapAmountInputButton?(sendTokenModel)
  }
  
  func didTapCommentButton() {
    let sendTokenModel = SendModel(
      wallet: sendController.selectedFromWallet,
      recipient: sendController.inputRecipient,
      sendItem: sendController.sendItem,
      comment: sendController.comment
    )
    self.didTapCommentInputButton?(sendTokenModel)
  }
  
  func didTapContinueButton() {
    guard let recipient = sendController.selectedRecipient else { return }
    didContinueSend?(
      SendModel(
        wallet: sendController.selectedFromWallet,
        recipient: recipient,
        sendItem: sendController.sendItem,
        comment: sendController.comment
      )
    )
  }
  
  func didSelectFromWalletAtIndex(_ index: Int) {
    sendController.setWalletSelectedSender(index: index)
  }
  
  func didSelectRecipientAtIndex(_ index: Int) {
    if index == 0 {
      sendController.setInputRecipientSelectedRecipient()
    } else {
      sendController.setWalletSelectedRecipient(index: index - 1)
    }
  }
  
  // MARK: - State
  
  private var toWalletsModels = [SendPickerCell.Model]()
  private var recipientModel: SendPickerCell.Model?
  
  // MARK: - Image
  
  private let imageLoader = ImageLoader()

  // MARK: - Dependencies
  
  private let sendController: SendController
  
  // MARK: - Init
  
  init(sendController: SendController) {
    self.sendController = sendController
  }
}

private extension SendViewModelImplementation {
  func bindControllerEvents() {
    sendController.didUpdateFromWallets = { [weak self] models in
      guard let self = self else { return }
      let items = self.mapFromWallets(models: models)
      didUpdateWalletPickerItems?(items)
    }
    
    sendController.didUpdateSelectedFromWallet = { [weak self] index in
      self?.didUpdateWalletPickerSelectedItemIndex?(index)
    }
    
    sendController.didUpdateToWallets = { [weak self] in
      guard let self = self else { return }
      self.toWalletsModels = mapToWallets(models: $0)
      var items = [SendPickerCell.Model]()
      if let recipientModel {
        items.append(recipientModel)
      }
      items.append(contentsOf: toWalletsModels)
      didUpdateRecipientPickerItems?(items)
    }
    
    sendController.didUpdateInputRecipient = { [weak self] in
      guard let self = self else { return }
      self.recipientModel = mapRecipient($0)
      var items = [SendPickerCell.Model]()
      if let recipientModel {
        items.append(recipientModel)
      }
      items.append(contentsOf: toWalletsModels)
      didUpdateRecipientPickerItems?(items)
    }
    
    sendController.didUpdateIsSendAvailable = { [weak self] isAvailable in
      self?.didUpdateContinueButtonIsEnabled?(isAvailable)
    }
    
    sendController.didUpdateSendItem = { [weak self] in
      guard let self else { return }
      let model = self.sendController.getSendItemModel()
      let viewModel = self.mapSendItemViewModel(sendItemModel: model)
      self.didUpdateSendItem?(viewModel)
    }
    
    sendController.didUpdateComment = { [weak self] in
      guard let self = self else { return }
      self.didUpdateComment?(self.sendController.getComment())
    }
  }
  
  func mapFromWallets(models: [SendController.SendWalletModel]) -> [SendPickerCell.Model] {
    models.map { model in
      let rightView: SendPickerCell.RightView.Model
      if let balance = model.balance {
        rightView = .amount(
          SendPickerCell.AmountView.Model(
            amount: balance.withTextStyle(.body1, color: .Text.primary, alignment: .left),
            isPickEnable: model.isPickerEnabled
          )
        )
      } else {
        rightView = .empty(SendPickerCell.EmptyAccessoriesView.Model(buttons: []))
      }
    
      return SendPickerCell.Model(
        id: model.id,
        informationModel: SendPickerCell.InformationView.Model(
          topText: "From:".withTextStyle(.body1, color: .Text.secondary, alignment: .left),
          bottomText: model.name.withTextStyle(.body1, color: .Text.primary, alignment: .left)
        ),
        rightView: rightView
      )
    }
  }
  
  func mapToWallets(models: [SendController.SendWalletModel]) -> [SendPickerCell.Model] {
    models.map { model in
      let rightView: SendPickerCell.RightView.Model
      if let balance = model.balance {
        rightView = .amount(
          SendPickerCell.AmountView.Model(
            amount: balance.withTextStyle(.body1, color: .Text.primary, alignment: .left),
            isPickEnable: model.isPickerEnabled
          )
        )
      } else {
        rightView = .empty(SendPickerCell.EmptyAccessoriesView.Model(buttons: []))
      }
      
      return SendPickerCell.Model(
        id: model.id,
        informationModel: SendPickerCell.InformationView.Model(
          topText: "To:".withTextStyle(.body1, color: .Text.secondary, alignment: .left),
          bottomText: model.name.withTextStyle(.body1, color: .Text.primary, alignment: .left)
        ),
        rightView: rightView
      )
    }
  }
  
  func mapRecipient(_ recipient: SendController.SendRecipientModel) -> SendPickerCell.Model {
    let rightView: SendPickerCell.RightView.Model
    if recipient.isEmpty {
      rightView = .empty(
        SendPickerCell.EmptyAccessoriesView.Model(
          buttons: [
            SendPickerCell.EmptyAccessoriesView.Model.Button(
              model: TKHeaderButton.Model(title: "Paste"),
              action: { [weak self] in
                guard let pasteboardString = UIPasteboard.general.string else { return }
                self?.sendController.setInputRecipient(with: pasteboardString)
              }
            )
          ]
        )
      )
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
  
  func mapSendItemViewModel(sendItemModel: KeeperCore.SendController.SendItemModel) -> SendItemViewModel {
    switch sendItemModel {
    case .token(let value):
      return .token(value: value)
    case .nft(let nft):
      let nftModel = NFTView.Model(
        imageDownloadTask: TKCore.ImageDownloadTask(closure: {
          [imageLoader] imageView,
          size,
          cornerRadius in
          imageLoader.loadImage(
            url: nft.imageUrl,
            imageView: imageView,
            size: size,
            cornerRadius: cornerRadius
          )
        }),
        name: nft.name,
        collectionName: nft.collectionName,
        action: {}
      )
      
      return .nft(nftModel: nftModel)
    }
  }
}
