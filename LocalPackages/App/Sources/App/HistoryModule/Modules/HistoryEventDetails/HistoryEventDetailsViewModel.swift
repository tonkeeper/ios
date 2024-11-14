import Foundation
import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

protocol HistoryEventDetailsModuleOutput: AnyObject {
  var didTapOpenTransactionInTonviewer: (() -> Void)? { get set }
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload, _ eventId: String) -> Void)? { get set }
}

protocol HistoryEventDetailsViewModel: AnyObject {
  
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryEventDetailsViewModelImplementation: HistoryEventDetailsViewModel, HistoryEventDetailsModuleOutput {
  
  // MARK: - HistoryEventDetailsModuleOutput
  
  var didTapOpenTransactionInTonviewer: (() -> Void)?
  var didSelectEncryptedComment: ((Wallet, EncryptedCommentPayload, String) -> Void)?
  
  // MARK: - HistoryEventDetailsViewModel
  
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupContent()
    
    decryptedCommentStore.addObserver(self) { observer, event in
      switch event {
      case let .didDecryptComment(eventId, wallet):
        DispatchQueue.main.async {
          guard observer.event.accountEvent.eventId == eventId, wallet == observer.wallet else {
            return
          }
          observer.setupContent()
        }
      }
    }
  }
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let event: AccountEventDetailsEvent
  private let historyEventDetailsMapper: HistoryEventDetailsMapper
  private let decryptedCommentStore: DecryptedCommentStore
  
  // MARK: - Init
  
  init(wallet: Wallet,
       event: AccountEventDetailsEvent,
       historyEventDetailsMapper: HistoryEventDetailsMapper,
       decryptedCommentStore: DecryptedCommentStore) {
    self.wallet = wallet
    self.event = event
    self.historyEventDetailsMapper = historyEventDetailsMapper
    self.decryptedCommentStore = decryptedCommentStore
  }
}

private extension HistoryEventDetailsViewModelImplementation {
  
  func setupContent() {
    let model = self.historyEventDetailsMapper.mapEvent(
      event: event) { eventId, payload in
        decryptedCommentStore.getDecryptedComment(wallet: wallet, payload: payload, eventId: eventId)
      }
    self.configure(model: model)
  }
  
  func configure(model: HistoryEventDetailsMapper.Model) {
    var items = [TKPopUp.Item]()
    
    if let spamItem = configureSpamItem(model: model) {
      items.append(spamItem)
    }
    if let headerImage = configureHeaderImage(model: model) {
      items.append(headerImage)
    }
    
    let labelsGroup: TKPopUp.Component.GroupComponent = {
      var items = [TKPopUp.Item]()
      
      items.append(contentsOf: configureNFTItems(model: model))
      
      if let aboveTitle = model.aboveTitle {
        items.append(TKPopUp.Component.LabelComponent(
          text: aboveTitle.withTextStyle(.h2, color: .Text.tertiary, alignment: .center),
          numberOfLines: 1,
          bottomSpace: 4)
        )
      }
      if let title = model.title {
        items.append(TKPopUp.Component.LabelComponent(
          text: title.withTextStyle(.h2, color: .Text.primary, alignment: .center),
          numberOfLines: 1,
          bottomSpace: 4)
        )
      }
      if let fiatPrice = model.fiatPrice {
        items.append(TKPopUp.Component.LabelComponent(
          text: fiatPrice.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
          numberOfLines: 1,
          bottomSpace: 4)
        )
      }
      if let date = model.date {
        items.append(TKPopUp.Component.LabelComponent(
          text: date.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
          numberOfLines: 1,
          bottomSpace: 0)
        )
      }
      if let status = model.status {
        items.append(TKPopUp.Component.LabelComponent(
          text: status.withTextStyle(.body1, color: .Accent.orange, alignment: .center),
          numberOfLines: 1,
          bottomSpace: 0)
        )
      }
      return TKPopUp.Component.GroupComponent(
        padding: UIEdgeInsets(top: 0, left: 32, bottom: 32, right: 32),
        items: items
      )
    }()
    items.append(labelsGroup)
    if let listItem = configureListItems(model: model) {
      items.append(
        TKPopUp.Component.GroupComponent(
          padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
          items: [listItem]
        )
      )
    }
    
    items.append(TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0),
      items: [configureTransactionButton()]
    ))
    
    let configuration = TKPopUp.Configuration(items: items)
    
    didUpdateConfiguration?(configuration)
  }
  
  func configureSpamItem(model: HistoryEventDetailsMapper.Model) -> TKPopUp.Item? {
    guard model.isScam else { return nil }
    return HistoryEventDetailsSpamComponent(
      configuration: HistoryEventDetailsSpamView.Configuration(
        title: TKLocales.ActionTypes.spam.uppercased().withTextStyle(
          .label2,
          color: .Constant.white,
          alignment: .center
        )
      ),
      bottomSpace: 12
    )
  }
  
  func configureHeaderImage(model: HistoryEventDetailsMapper.Model) -> TKPopUp.Item? {
    guard !model.isScam else { return nil }
    guard let headerImage = model.headerImage else { return nil }
    
    switch headerImage {
    case .image(let tokenImage):
      return TKPopUp.Component.ImageComponent(
        image: TKImageView.Model(image: tokenImage.tkImage,
                                 tintColor: .Icon.primary,
                                 size: .size(CGSize(width: 76, height: 76)),
                                 corners: .circle,
                                 padding: .zero),
        bottomSpace: 20
      )
    case .swap(let fromImage, let toImage):
      return HistoryEventDetailsSwapHeaderComponent(
        configuration: HistoryEventDetailsSwapHeaderView.Configuration(
          leftImageModel: TKImageView.Model(
            image: fromImage.tkImage,
            tintColor: .Icon.primary,
            size: .size(CGSize(width: 76, height: 76)),
            corners: .circle
          ),
          rightImageModel: TKImageView.Model(
            image: toImage.tkImage,
            tintColor: .Icon.primary,
            size: .size(CGSize(width: 76, height: 76)),
            corners: .circle
          )
        ),
        bottomSpace: 20
      )
    case .nft(let url):
      return TKPopUp.Component.ImageComponent(
        image: TKImageView.Model(image: TKImage.urlImage(url),
                                 size: .size(CGSize(width: 96, height: 96)),
                                 corners: .cornerRadius(cornerRadius: 20),
                                 padding: .zero),
        bottomSpace: 20
      )
    }
  }
  
  func configureNFTItems(model: HistoryEventDetailsMapper.Model) -> [TKPopUp.Item] {
    guard !model.isScam else { return [] }
    guard let nftModel = model.nftModel else { return [] }
    guard let nftName = nftModel.name else { return [] }
    var items = [TKPopUp.Item]()
    items.append(TKPopUp.Component.LabelComponent(text: nftName.withTextStyle(.h2, color: .Text.primary, alignment: .center)))
    if let collectionName = nftModel.collectionName {
      items.append(
        HistoryEventDetailsNFTCollectionComponent(
          configuration: HistoryEventDetailsNFTCollectionView.Configuration(
            name: collectionName,
            isVerified: nftModel.isVerified
          ),
          bottomSpace: 16
        )
      )
    }
    return items
  }
  
  private func configureListItems(model: HistoryEventDetailsMapper.Model) -> TKPopUp.Component.List? {
    guard !model.listItems.isEmpty else { return nil }
    return TKPopUp.Component.List(
      configuration: TKListContainerView.Configuration(
        items: model.listItems.map {
          listItem in
          configureListItem(listItem)
        },
        copyToastConfiguration: .copied
      )
    )
  }
  
  private func configureListItem(_ modelListItem: HistoryEventDetailsMapper.Model.ListItem) -> TKListContainerItem {
    let item: TKListContainerItem
    switch modelListItem {
    case .recipient(let value, let copyValue):
      item = TKListContainerItemView.Model(
        title: TKLocales.EventDetails.recipient,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: value)
          )
        ),
        action: .copy(copyValue: copyValue)
      )
    case .recipientAddress(let value, let copyValue):
      item = TKListContainerFullValueItemItem(
        title: TKLocales.EventDetails.recipientAddress,
        value: value,
        copyValue: copyValue
      )
    case .sender(let value, let copyValue):
      item = TKListContainerItemView.Model(
        title: TKLocales.EventDetails.sender,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: value)
          )
        ),
        action: .copy(copyValue: copyValue)
      )
    case .senderAddress(let value, let copyValue):
      item = TKListContainerFullValueItemItem(
        title: TKLocales.EventDetails.senderAddress,
        value: value,
        copyValue: copyValue
      )
    case let .fee(value, converted):
      item = TKListContainerItemView.Model(
        title: TKLocales.EventDetails.fee,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: value),
            bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: converted)
          )
        ),
        action: nil
      )
    case .refund(let value, let converted):
      item = TKListContainerItemView.Model(
        title: "Refund",
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: value),
            bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: converted)
          )
        ),
        action: nil
      )
    case .comment(let string):
      item = TKListContainerItemView.Model(
        title: TKLocales.EventDetails.comment,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: string, numberOfLines: 0)
          )
        ),
        action: .copy(copyValue: string)
      )
    case .encryptedComment(let encryptedComment):
      let value: HistoryEventDetailsListContainerItemEncryptedCommenValueView.Configuration = {
        switch encryptedComment {
        case .decrypted(let value):
            .decrypted(text: value)
        case .encrypted(let payload):
            .encrypted(text: payload.encryptedComment.cipherText)
        }
      }()
      
      let action: TKListContainerItemAction = {
        switch encryptedComment {
        case .decrypted(let value):
          return .copy(copyValue: value)
        case .encrypted(let payload):
          return .custom { [weak self, wallet, event] in
            self?.didSelectEncryptedComment?(wallet, payload, event.accountEvent.eventId)
          }
        }
      }()
      
      item = TKListContainerItemView.Model(
        id: "encrypted_comment_item",
        title: TKLocales.EventDetails.comment,
        titleIcon: TKListContainerItemView.Model.Icon(
          image: .TKUIKit.Icons.Size12.lock,
          tintColor: .Accent.green
        ),
        value: .value(
          value
        ),
        action: action
      )
    case .description(let string):
      item = TKListContainerItemView.Model(
        title: TKLocales.EventDetails.description,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: string, numberOfLines: 0)
          )
        ),
        action: .copy(copyValue: string)
      )
    case .operation(let value):
      item = TKListContainerItemView.Model(
        title: TKLocales.EventDetails.operation,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: value, numberOfLines: 0)
          )
        ),
        action: .copy(copyValue: value)
      )
    case let .other(title, value, copyValue):
      item = TKListContainerItemView.Model(
        title: title,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: value, numberOfLines: 0)
          )
        ),
        action: .copy(copyValue: copyValue)
      )
    }
    return item
  }
  
  func configureTransactionButton() -> HistoryEventDetailsTransactionButtonComponent {
    let transaction = TKLocales.EventDetails.transaction.withTextStyle(.label1, color: .Text.primary)
    let hash = String(event.accountEvent.eventId.prefix(8)).withTextStyle(.label1, color: .Text.secondary)
    let title = NSMutableAttributedString(attributedString: transaction)
    title.append(hash)
    
    return HistoryEventDetailsTransactionButtonComponent(
      configuration: HistoryEventDetailsTransactionButtonView.Configuration(
        title: title,
        action: { [weak self] in
          self?.didTapOpenTransactionInTonviewer?()
        }
      ),
      bottomSpace: 32
    )
  }
}

private extension TokenImage {
  var tkImage: TKImage {
    switch self {
    case .ton:
      return .image(.TKUIKit.Icons.Size44.tonCurrency)
    case .url(let url):
      return .urlImage(url)
    }
  }
}
