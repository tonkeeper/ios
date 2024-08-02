import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TonSwift

struct HistoryEventMapper {
  
  let imageLoader = ImageLoader()
  let accountEventActionContentProvider: AccountEventActionContentProvider
  
  init(accountEventActionContentProvider: AccountEventActionContentProvider) {
    self.accountEventActionContentProvider = accountEventActionContentProvider
  }
  
  func mapEvent(_ event: AccountEventModel,
                nftAction: @escaping (Address) -> Void,
                encryptedCommentAction: @escaping () -> Void,
                tapAction: @escaping (AccountEventDetailsEvent) -> Void) -> HistoryCell.Model {
    return HistoryCell.Model(
      id: event.eventId,
      historyContentConfiguration: mapEventContentConfiguration(
        event,
        nftAction: nftAction,
        encryptedCommentAction: encryptedCommentAction,
        tapAction: tapAction
      )
    )
  }
  
  func mapEventContentConfiguration(_ event: AccountEventModel,
                                    nftAction: @escaping (Address) -> Void,
                                    encryptedCommentAction: @escaping () -> Void,
                                    tapAction: @escaping (AccountEventDetailsEvent) -> Void) -> HistoryCellContentView.Model {
    let actions = event.actions.enumerated().map { index, action in
      HistoryCellContentView.Model.Action(
        configuration: mapAction(
          action, 
          isInProgress: event.accountEvent.isInProgress,
          nftAction: nftAction,
          encryptedCommentAction: encryptedCommentAction),
        action: {
          tapAction(AccountEventDetailsEvent(accountEvent: event.accountEvent, action: event.accountEvent.actions[index]))
        }
      )
    }
    return HistoryCellContentView.Model(actions: actions)
  }

  func mapAction(_ action: AccountEventModel.Action,
                 isInProgress: Bool,
                 nftAction: @escaping (Address) -> Void,
                 encryptedCommentAction: @escaping () -> Void) -> HistoryCellActionView.Model {
    let imageModel = TKUIListItemImageIconView.Configuration(
      image: .image(action.eventType.icon),
      tintColor: .Icon.secondary,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      cornerRadius: 22
    )
    let iconConfiguration = HistoryCellIconView.Configuration(
      imageModel: imageModel
    )

    let title = accountEventActionContentProvider.title(actionType: action.eventType)?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = action.leftTopDescription?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let date = action.rightTopDescription?.withTextStyle(.body2, color: .Text.secondary, alignment: .right)
    
    let valueTextStyle = TKTextStyle(
      font: .montserratSemiBold(size: 16),
      lineHeight: 22
    )
    
    let valueResult = NSMutableAttributedString()
    if let amount = action.amount {
      valueResult.append(
        amount.withTextStyle(
          valueTextStyle,
          color: action.eventType.amountColor,
          alignment: .right,
          lineBreakMode: .byTruncatingTail
        )
      )
      if let subamount = action.subamount {
        valueResult.append(NSAttributedString(string: "\n"))
        valueResult.append(
          subamount.withTextStyle(
            valueTextStyle,
            color: action.eventType.subamountColor,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
          )
        )
      }
    }
    
    let status = action.status?.withTextStyle(
      .body2,
      color: .Accent.orange,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: subtitle,
      description: status,
      descriptionNumberOfLines: 1
    )
    let rightItemConfiguration = TKUIListItemContentRightItem.Configuration(
      value: valueResult,
      valueNumberOfLines: 0,
      subtitle: date,
      description: nil
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: leftItemConfiguration,
      rightItemConfiguration: rightItemConfiguration,
      isVerticalCenter: false
    )

    var commentConfiguration: HistoryCellActionView.CommentView.Configuration?
    if let comment = action.comment {
      commentConfiguration = HistoryCellActionView.CommentView.Configuration(comment: comment)
    }
    
    var encryptedCommentConfiguration: HistoryCellActionView.EncyptedCommentView.Model?
    if let encryptedComment = action.encryptedComment {
      encryptedCommentConfiguration = HistoryCellActionView.EncyptedCommentView.Model(
        encryptedText: encryptedComment.cipherText,
        action: {
          encryptedCommentAction()
        }
      )
    }
    
    var descriptionConfiguration: HistoryCellActionView.CommentView.Configuration?
    if let description = action.description {
      descriptionConfiguration = HistoryCellActionView.CommentView.Configuration(comment: description)
    }
    
    var nftConfiguration: HistoryCellActionView.NFTView.Configuration?
    if let nft = action.nft {
      switch nft {
      case .model(let model):
        let nftItem = HistoryCellActionView.NFTView.Configuration.NFT(
          imageDownloadTask: TKCore.ImageDownloadTask(closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            imageLoader.loadImage(
              url: model.image,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }),
          imageUrl: model.image,
          name: model.name,
          collectionName: model.collectionName,
          action: {
            nftAction(model.nft.address)
          }
        )
        nftConfiguration = .nft(nftItem)
      case .empty(let address):
        nftAction(address)
        nftConfiguration = .shimmer
      }
    }
    
    return HistoryCellActionView.Model(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      commentConfiguration: commentConfiguration,
      encryptedCommentConfiguration: encryptedCommentConfiguration,
      descriptionConfiguration: descriptionConfiguration,
      nftConfiguration: nftConfiguration,
      isInProgress: isInProgress
    )
  }
}

extension AccountEventModel.Action.ActionType {
  var icon: UIImage? {
    switch self {
    case .sent:
      return .App.Icons.Size28.trayArrowUp
    case .receieved:
      return .App.Icons.Size28.trayArrowDown
    case .mint:
      return .App.Icons.Size28.trayArrowDown
    case .burn:
      return .App.Icons.Size28.trayArrowUp
    case .depositStake:
      return .App.Icons.Size28.trayArrowUp
    case .withdrawStake:
      return .App.Icons.Size28.trayArrowUp
    case .withdrawStakeRequest:
      return .App.Icons.Size28.trayArrowDown
    case .jettonSwap:
      return .App.Icons.Size28.swapHorizontalAlternative
    case .spam:
      return .App.Icons.Size28.trayArrowDown
    case .bounced:
      return .App.Icons.Size28.return
    case .subscribed:
      return .App.Icons.Size28.bell
    case .unsubscribed:
      return .App.Icons.Size28.xmark
    case .walletInitialized:
      return .App.Icons.Size28.donemark
    case .contractExec:
      return .App.Icons.Size28.gear
    case .nftCollectionCreation:
      return .App.Icons.Size28.gear
    case .nftCreation:
      return .App.Icons.Size28.gear
    case .removalFromSale:
      return .App.Icons.Size28.xmark
    case .nftPurchase:
      return .App.Icons.Size28.shoppingBag
    case .bid:
      return .App.Icons.Size28.trayArrowUp
    case .putUpForAuction:
      return .App.Icons.Size28.trayArrowUp
    case .endOfAuction:
      return .App.Icons.Size28.xmark
    case .putUpForSale:
      return .App.Icons.Size28.trayArrowUp
    case .domainRenew:
      return .App.Icons.Size28.return
    case .unknown:
      return .App.Icons.Size28.gear
    }
  }
  
  var amountColor: UIColor {
    switch self {
    case .sent,
        .depositStake,
        .subscribed,
        .unsubscribed,
        .walletInitialized,
        .nftCollectionCreation,
        .nftCreation,
        .removalFromSale,
        .nftPurchase,
        .bid,
        .putUpForAuction,
        .endOfAuction,
        .contractExec,
        .putUpForSale,
        .burn,
        .domainRenew,
        .unknown:
      return .Text.primary
    case .receieved, .bounced, .mint, .withdrawStake, .jettonSwap:
      return .Accent.green
    case .spam, .withdrawStakeRequest:
      return .Text.tertiary
    }
  }
  
  var subamountColor: UIColor {
    switch self {
    case .jettonSwap:
      return .Text.primary
    default:
      return .Text.primary
    }
  }
}
