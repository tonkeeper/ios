import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

protocol SendConfirmationModuleOutput: AnyObject {
  var didSendTransaction: (() -> Void)? { get set }
  var didRequireSign: ((TransferMessageBuilder, Wallet) async throws -> String?)? { get set }
}

protocol SendConfirmationModuleInput: AnyObject {
  
}

protocol SendConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
}

final class SendConfirmationViewModelImplementation: SendConfirmationViewModel, SendConfirmationModuleOutput, SendConfirmationModuleInput {
  
  // MARK: - SendConfirmationModuleOutput
  
  var didSendTransaction: (() -> Void)?
  
  var didRequireSign: ((TransferMessageBuilder, Wallet) async throws -> String?)?
  
  // MARK: - SendConfirmationModuleInput
  
  // MARK: - SendConfirmationViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    Task {
      await sendConfirmationController.start()
    }
  }
  
  func viewDidAppear() {
    
  }
  
  func viewWillDisappear() {
    
  }
  
  // MARK: - Dependencies
  
  private let sendConfirmationController: SendConfirmationController
  
  // MARK: - Init
  
  init(sendConfirmationController: SendConfirmationController) {
    self.sendConfirmationController = sendConfirmationController
  }
}

private extension SendConfirmationViewModelImplementation {
  func setupControllerBindings() {
    sendConfirmationController.didUpdateModel = { [weak self] sendConfirmationModel in
      guard let self else { return }
      let configuration = self.mapSendConfirmationModel(sendConfirmationModel)
      self.didUpdateConfiguration?(configuration)
    }
    
    sendConfirmationController.signHandler = { [weak self] transferBuilder, wallet in
      try await self?.didRequireSign?(transferBuilder, wallet)
    }
  }
  
  func mapSendConfirmationModel(_ sendConfirmationModel: SendConfirmationModel) -> TKModalCardViewController.Configuration {
    
    let headerView: UIView
    switch sendConfirmationModel.image {
    case .ton:
      let view = HistoreEventDetailsTokenHeaderImageView()
      view.configure(
        model: HistoreEventDetailsTokenHeaderImageView.Model(
          image: .image(
            .TKUIKit.Icons.Size96.tonIcon,
            tinColor: nil,
            backgroundColor: nil
          )
        )
      )
      headerView = view
    case .jetton(let url):
      let view = HistoreEventDetailsTokenHeaderImageView()
      view.imageLoader = ImageLoader()
      view.configure(model: HistoreEventDetailsTokenHeaderImageView.Model(image: .url(url)))
      headerView = view
    case .nft(let url):
      let view = HistoryEventDetailsNFTHeaderImageView()
      view.imageLoader = ImageLoader()
      view.configure(model: HistoryEventDetailsNFTHeaderImageView.Model(image: .url(url), size: CGSize(width: 96, height: 96)))
      headerView = view
    }
    
    let description: String
    switch sendConfirmationModel.descriptionType {
    case .jetton, .ton:
      description = TKLocales.ConfirmSend.TokenTransfer.title
    case .nft(let value):
      description = value
    }
    
    let title: String
    switch sendConfirmationModel.titleType {
    case .ton:
      title = TKLocales.ConfirmSend.TokenTransfer.transfer("TON")
    case .jetton(let symbol):
      title = TKLocales.ConfirmSend.TokenTransfer.transfer(symbol)
    case .nft:
      title = TKLocales.ConfirmSend.TokenTransfer.transfer("NFT")
    }
    
    let header = TKModalCardViewController.Configuration.Header(
      items: [
        .customView(headerView, bottomSpacing: 20),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: description.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
            numberOfLines: 1
          ),
          bottomSpacing: 4
        ),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: title.withTextStyle(.h3, color: .Text.primary, alignment: .center),
            numberOfLines: 1
          ),
          bottomSpacing: 0
        )
      ]
    )
    
    var listItems = [TKModalCardViewController.Configuration.ListItem]()
    
    let senderWalletName = sendConfirmationModel.wallet.iconWithName(
      attributes: TKTextStyle.label1.getAttributes(color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail),
      iconColor: .Icon.primary,
      iconSide: 20
    )
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: TKLocales.ConfirmSend.wallet,
        rightTop: .value(senderWalletName, numberOfLines: 0, isFullString: false),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    if let recipientName = sendConfirmationModel.recipientName {
      listItems.append(
        TKModalCardViewController.Configuration.ListItem.defaultItem(
          left: TKLocales.ConfirmSend.Recipient.title,
          rightTop: .value(recipientName, numberOfLines: 0, isFullString: true),
          rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
        )
      )
    }
    if let recipientAddress = sendConfirmationModel.recipientAddress {
      listItems.append(
        TKModalCardViewController.Configuration.ListItem.defaultItem(
          left: TKLocales.ConfirmSend.Recipient.address,
          rightTop: .value(recipientAddress, numberOfLines: 1, isFullString: false),
          rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
        )
      )
    }
    if let amount = sendConfirmationModel.amount {
      let rightBottom: TKModalCardViewController.Configuration.ListItem.RightItem<String?>
      switch sendConfirmationModel.amountConverted {
      case .loading:
        rightBottom = .loading
      case .value(let value):
        rightBottom = .value(value, numberOfLines: 1, isFullString: false)
      }
      listItems.append(
        TKModalCardViewController.Configuration.ListItem.defaultItem(
          left: TKLocales.ConfirmSend.amount,
          rightTop: .value(amount, numberOfLines: 0, isFullString: false),
          rightBottom: rightBottom
        )
      )
    }
    
    let feeRightTop: TKModalCardViewController.Configuration.ListItem.RightItem<String>
    switch sendConfirmationModel.fee {
    case .loading:
      feeRightTop = .loading
    case .value(let value):
      feeRightTop = .value(value, numberOfLines: 1, isFullString: false)
    }
    let feeRightBottom: TKModalCardViewController.Configuration.ListItem.RightItem<String?>
    switch sendConfirmationModel.feeConverted {
    case .loading:
      feeRightBottom = .loading
    case .value(let value):
      feeRightBottom = .value(value, numberOfLines: 1, isFullString: false)
    }
    listItems.append(
      TKModalCardViewController.Configuration.ListItem.defaultItem(
        left: TKLocales.ConfirmSend.fee,
        rightTop: feeRightTop,
        rightBottom: feeRightBottom
      )
    )
    
    if let comment = sendConfirmationModel.comment, !comment.isEmpty {
      listItems.append(
        TKModalCardViewController.Configuration.ListItem.defaultItem(
          left: TKLocales.ConfirmSend.comment,
          rightTop: .value(comment, numberOfLines: 0, isFullString: false),
          rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
        )
      )
    }
    
    let content = TKModalCardViewController.Configuration.Content(items: [
      .list(listItems)
    ])
    
    let actionBar = TKModalCardViewController.Configuration.ActionBar(
      items: [
        .button(
          TKModalCardViewController.Configuration.Button(
            title: TKLocales.ConfirmSend.confirm_button,
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: { [weak self] isActivityClosure, isSuccessClosure in
              guard let self = self else { return }
              isActivityClosure(true)
              Task {
                let isSuccess = await self.sendTransaction()
                await MainActor.run {
                  isSuccessClosure(isSuccess)
                }
              }
            },
            completionAction: { [weak self] isSuccess in
              guard let self, isSuccess else { return }
              self.didSendTransaction?()
            }
          ),
          bottomSpacing: 0
        )
      ]
    )
    
    return TKModalCardViewController.Configuration(
      header: header,
      content: content,
      actionBar: actionBar
    )
  }
  
  func sendTransaction() async -> Bool {
    do {
      try await sendConfirmationController.sendTransaction()
      return true
    } catch {
      return false
    }
  }
}
