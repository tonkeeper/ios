import UIKit
import TKUIKit
import UIComponents
import Resources
import Core
import KeeperCore
import TonSwift
import TKLocalize

public struct AccountEventModelMapper {
  
  private let accountEventModelActionContentProvider: AccountEventModelActionContentProvider
  
  public init(accountEventModelActionContentProvider: AccountEventModelActionContentProvider) {
    self.accountEventModelActionContentProvider = accountEventModelActionContentProvider
  }
  
  public func mapEvent(_ event: AccountEventModel,
                       isSecureMode: Bool,
                       nftAction: @escaping (Address) -> Void,
                       encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void,
                       tapAction: @escaping (AccountEventDetailsEvent) -> Void) -> AccountEventCell.Model {
    return AccountEventCell.Model(
      id: event.eventId,
      accountEventContentConfiguration: mapEventContentConfiguration(
        event,
        isSecureMode: isSecureMode,
        nftAction: nftAction,
        encryptedCommentAction: encryptedCommentAction,
        tapAction: tapAction
      )
    )
  }
  
  public func mapSignRawEventContentConfiguration(_ event: AccountEventModel,
                                                  fee: String,
                                                  feeConverted: String?,
                                                  feeDescription: String?) -> AccountEventCellContentView.Model{
    var actions = event.actions.enumerated().map { index, action in
      AccountEventCellContentView.Model.Action(
        configuration: mapAction(
          action,
          isInProgress: event.accountEvent.isInProgress,
          isSecureMode: false,
          nftAction: { _ in },
          encryptedCommentAction: { _ in }),
        action: {}
      )
    }
    
    actions.append(
      AccountEventCellContentView.Model.Action(
        configuration: mapFee(
          fee: fee,
          feeConverted: feeConverted,
          feeDescription: feeDescription
        ),
        action: {
        }
      )
    )
    return AccountEventCellContentView.Model(actions: actions)
  }
  
  public func mapEventContentConfiguration(_ event: AccountEventModel,
                                           isSecureMode: Bool,
                                           nftAction: @escaping (Address) -> Void,
                                           encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void,
                                           tapAction: @escaping (AccountEventDetailsEvent) -> Void) -> AccountEventCellContentView.Model {
    let actions = event.actions.enumerated().map { index, action in
      AccountEventCellContentView.Model.Action(
        configuration: mapAction(
          action,
          isInProgress: event.accountEvent.isInProgress,
          isSecureMode: isSecureMode,
          nftAction: nftAction,
          encryptedCommentAction: encryptedCommentAction),
        action: {
          tapAction(AccountEventDetailsEvent(accountEvent: event.accountEvent, action: event.accountEvent.actions[index]))
        }
      )
    }
    return AccountEventCellContentView.Model(actions: actions)
  }
  
  func mapAction(_ action: AccountEventModel.Action,
                 isInProgress: Bool,
                 isSecureMode: Bool,
                 nftAction: @escaping (Address) -> Void,
                 encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void) -> AccountEventCellActionView.Model {
    
    var icon: UIImage? {
      switch action.stakingImplementation {
      case .liquidTF:
        return .TKUIKit.Icons.Size44.tonStakersLogo
      case .whales:
        return .TKUIKit.Icons.Size44.tonWhalesLogo
      case .tf:
        return .TKUIKit.Icons.Size44.tonNominatorsLogo
      case .unknown, .none:
        return action.eventType.icon
      }
    }
    
    let imageModel = TKUIListItemImageIconView.Configuration(
      image: .image(icon),
      tintColor: .Icon.secondary,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      cornerRadius: 22
    )
    let iconConfiguration = AccountEventCellIconView.Configuration(
      imageModel: imageModel
    )
    
    let title = accountEventModelActionContentProvider.title(actionType: action.eventType)?.withTextStyle(
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
        (isSecureMode ? String.secureModeValueShort : amount).withTextStyle(
          valueTextStyle,
          color: action.eventType.amountColor,
          alignment: .right,
          lineBreakMode: .byTruncatingTail
        )
      )
      if let subamount = action.subamount {
        valueResult.append(NSAttributedString(string: "\n"))
        valueResult.append(
          (isSecureMode ? String.secureModeValueShort : subamount).withTextStyle(
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
    
    var commentConfiguration: AccountEventCellActionView.CommentView.Configuration?
    if let comment = action.comment, action.eventType != .spam {
      commentConfiguration = AccountEventCellActionView.CommentView.Configuration(comment: comment)
    }
    
    var encryptedCommentConfiguration: AccountEventCellActionView.EncyptedCommentView.Model?
    if let encryptedComment = action.encryptedComment {
      switch encryptedComment {
      case .encrypted(let payload):
        encryptedCommentConfiguration = AccountEventCellActionView.EncyptedCommentView.Model(
          encryptedText: payload.encryptedComment.cipherText,
          action: {
            encryptedCommentAction(payload)
          }
        )
      case .decrypted(let decrypted):
        encryptedCommentConfiguration = AccountEventCellActionView.EncyptedCommentView.Model(
          decryptedText: decrypted
        )
      }
    }
    
    var descriptionConfiguration: AccountEventCellActionView.CommentView.Configuration?
    if let description = action.description {
      descriptionConfiguration = AccountEventCellActionView.CommentView.Configuration(comment: description)
    }
    
    var nftConfiguration: AccountEventCellActionView.NFTView.Configuration?
    if let actionNft = action.nft {
      let imageViewModel = TKImageView.Model(
        image: TKImage.urlImage(actionNft.image),
        size: .size(CGSize(width: 64, height: 64))
      )
      
      nftConfiguration = AccountEventCellActionView.NFTView.Configuration(
        imageModel: imageViewModel,
        name: actionNft.name,
        collectionName: actionNft.collectionName,
        isSuspecious: actionNft.isSuspecious,
        isVerified: actionNft.nft.trust == .whitelist,
        isBlurVisible: isSecureMode,
        action: {
          nftAction(actionNft.nft.address)
        }
      )
    }
    
    return AccountEventCellActionView.Model(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      commentConfiguration: commentConfiguration,
      encryptedCommentConfiguration: encryptedCommentConfiguration,
      descriptionConfiguration: descriptionConfiguration,
      nftConfiguration: nftConfiguration,
      isInProgress: isInProgress
    )
  }
  
  private func mapFee(fee: String,
                      feeConverted: String?,
                      feeDescription: String?) -> AccountEventCellActionView.Model {
    let imageModel = TKUIListItemImageIconView.Configuration(
      image: .image(.TKUIKit.Icons.Size28.ton),
      tintColor: .Icon.secondary,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      cornerRadius: 22
    )
    let iconConfiguration = AccountEventCellIconView.Configuration(
      imageModel: imageModel
    )
    
    let title = TKLocales.EventDetails.fee.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = feeDescription?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let valueTextStyle = TKTextStyle(
      font: .montserratSemiBold(size: 16),
      lineHeight: 22
    )
    
    let value = fee.withTextStyle(
      valueTextStyle,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let feeSubtitle = feeConverted?.withTextStyle(.body2, color: .Text.secondary, alignment: .right)

    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: subtitle,
      description: nil,
      descriptionNumberOfLines: 1
    )
    let rightItemConfiguration = TKUIListItemContentRightItem.Configuration(
      value: value,
      valueNumberOfLines: 0,
      subtitle: feeSubtitle,
      description: nil
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: leftItemConfiguration,
      rightItemConfiguration: rightItemConfiguration,
      isVerticalCenter: false
    )

    return AccountEventCellActionView.Model(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      commentConfiguration: nil,
      encryptedCommentConfiguration: nil,
      descriptionConfiguration: nil,
      nftConfiguration: nil,
      isInProgress: false
    )
  }
}

extension AccountEventModel.Action.ActionType {
  var icon: UIImage? {
    switch self {
    case .sent:
      return .Resources.Icons.Size28.trayArrowUp
    case .receieved:
      return .Resources.Icons.Size28.trayArrowDown
    case .mint:
      return .Resources.Icons.Size28.trayArrowDown
    case .burn:
      return .Resources.Icons.Size28.trayArrowUp
    case .depositStake:
      return .Resources.Icons.Size28.trayArrowUp
    case .withdrawStake:
      return .Resources.Icons.Size28.trayArrowUp
    case .withdrawStakeRequest:
      return .Resources.Icons.Size28.trayArrowDown
    case .jettonSwap:
      return .Resources.Icons.Size28.swapHorizontalAlternative
    case .spam:
      return .Resources.Icons.Size28.trayArrowDown
    case .bounced:
      return .Resources.Icons.Size28.return
    case .subscribed:
      return .Resources.Icons.Size28.bell
    case .unsubscribed:
      return .Resources.Icons.Size28.xmark
    case .walletInitialized:
      return .Resources.Icons.Size28.donemark
    case .contractExec:
      return .Resources.Icons.Size28.gear
    case .nftCollectionCreation:
      return .Resources.Icons.Size28.gear
    case .nftCreation:
      return .Resources.Icons.Size28.gear
    case .removalFromSale:
      return .Resources.Icons.Size28.xmark
    case .nftPurchase:
      return .Resources.Icons.Size28.shoppingBag
    case .bid:
      return .Resources.Icons.Size28.trayArrowUp
    case .putUpForAuction:
      return .Resources.Icons.Size28.trayArrowUp
    case .endOfAuction:
      return .Resources.Icons.Size28.xmark
    case .putUpForSale:
      return .Resources.Icons.Size28.trayArrowUp
    case .domainRenew:
      return .Resources.Icons.Size28.return
    case .unknown:
      return .Resources.Icons.Size28.gear
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
