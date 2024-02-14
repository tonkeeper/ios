import UIKit
import TKUIKit
import KeeperCore
import TKCore

struct HistoryEventMapper {
  
  let imageLoader = ImageLoader()
  let accountEventActionContentProvider: AccountEventActionContentProvider
  
  init(accountEventActionContentProvider: AccountEventActionContentProvider) {
    self.accountEventActionContentProvider = accountEventActionContentProvider
  }
  
  func mapEvent(_ event: HistoryListEvent, 
                nftAction: @escaping (NFT) -> Void,
                tapAction: @escaping (AccountEventDetailsEvent) -> Void) -> HistoryEventCell.Model {
    let actions = event.actions.enumerated().map { index, action in
      let model = mapAction(action, nftAction: nftAction)
      return HistoryEventCellContentView.Model.Action(
        model: model,
        action: {
          tapAction(AccountEventDetailsEvent(accountEvent: event.accountEvent, action: event.accountEvent.actions[index]))
        }
      )
    }
    
    return HistoryEventCell.Model(
      identifier: event.eventId,
      cellContentModel: HistoryEventCellContentView.Model(
        actions: actions
      )
    )
  }
  
  func mapAction(_ action: HistoryListEvent.Action, nftAction: @escaping (NFT) -> Void) -> HistoryEventActionView.Model {
    let value = action.amount?.withTextStyle(
      .label1,
      color: action.eventType.amountColor,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let subvalue = action.subamount?.withTextStyle(
      .label1,
      color: action.eventType.subamountColor,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    let listItemModel = HistoryEventActionListItemView.Model(
      image: action.eventType.icon,
      isInProgress: false,
      title: accountEventActionContentProvider.title(actionType: action.eventType),
      subtitle: action.leftTopDescription,
      value: value,
      subvalue: subvalue,
      date: action.rightTopDescription
    )
    
    let statusModel = HistoryEventActionView.StatusView.Model(
      status: action.status?.withTextStyle(
        .body2,
        color: .Accent.orange,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    )
    
    var commentModel: HistoryEventActionView.CommentView.Model?
    if let comment = action.comment {
      commentModel = HistoryEventActionView.CommentView.Model(comment: comment.withTextStyle(.body2, color: .Text.primary))
    }
    
    var descriptionModel: HistoryEventActionView.CommentView.Model?
    if let description = action.description {
      descriptionModel = HistoryEventActionView.CommentView.Model(comment: description.withTextStyle(.body2, color: .Text.primary))
    }
    
    var nftModel: HistoryEventActionView.NFTView.Model?
    if let nft = action.nft {
      nftModel = HistoryEventActionView.NFTView.Model(
        imageDownloadTask: TKCore.ImageDownloadTask(closure: {
          [imageLoader] imageView,
          size,
          cornerRadius in
          imageLoader.loadImage(
            url: nft.image,
            imageView: imageView,
            size: size,
            cornerRadius: cornerRadius
          )
        }),
        name: nft.name,
        collectionName: nft.collectionName,
        action: {
          nftAction(nft.nft)
        }
      )
    }

    return HistoryEventActionView.Model(
      listItemModel: listItemModel,
      statusModel: statusModel,
      commentModel: commentModel,
      descriptionModel: descriptionModel,
      nftModel: nftModel
    )
  }
}

extension HistoryListEvent.Action.ActionType {
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
