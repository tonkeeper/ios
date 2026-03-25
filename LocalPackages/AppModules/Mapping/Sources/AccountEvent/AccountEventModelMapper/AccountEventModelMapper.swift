import Core
import KeeperCore
import Resources
import TKLocalize
import TKUIKit
import TonSwift
import UIComponents
import UIKit

public struct AccountEventModelMapper {
    private let accountEventModelActionContentProvider: AccountEventModelActionContentProvider

    public init(accountEventModelActionContentProvider: AccountEventModelActionContentProvider) {
        self.accountEventModelActionContentProvider = accountEventModelActionContentProvider
    }

    public func mapSignRawEventContentConfiguration(
        _ event: AccountEventModel,
        fee: String,
        feeConverted: String?,
        feeDescription: String?
    ) -> AccountEventCellContentView.Model {
        var actions = event.actions.enumerated().map { _, action in
            AccountEventCellContentView.Model.Action(
                configuration: mapAction(
                    action,
                    isInProgress: event.accountEvent.isInProgress,
                    isSecureMode: false,
                    nftAction: { _ in },
                    encryptedCommentAction: { _ in }
                ),
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
                action: {}
            )
        )
        return AccountEventCellContentView.Model(actions: actions)
    }

    public func mapEventContentConfiguration(
        _ event: AccountEventModel,
        isSecureMode: Bool,
        nftAction: @escaping (Address) -> Void,
        encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void,
        tapAction: @escaping (AccountEventDetailsEvent) -> Void
    ) -> AccountEventCellContentView.Model {
        let actions = event.actions.enumerated().map { index, action in
            AccountEventCellContentView.Model.Action(
                configuration: mapAction(
                    action,
                    isInProgress: event.accountEvent.isInProgress,
                    isSecureMode: isSecureMode,
                    nftAction: nftAction,
                    encryptedCommentAction: encryptedCommentAction
                ),
                action: {
                    tapAction(AccountEventDetailsEvent(accountEvent: event.accountEvent, action: event.accountEvent.actions[index]))
                }
            )
        }
        return AccountEventCellContentView.Model(actions: actions)
    }

    func mapAction(
        _ action: AccountEventModel.Action,
        isInProgress: Bool,
        isSecureMode: Bool,
        nftAction: @escaping (Address) -> Void,
        encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void
    ) -> AccountEventCellActionView.Model {
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

        var valueViewConfiguration: TKListItemTextView.Configuration?
        if let amount = action.amount {
            valueViewConfiguration = TKListItemTextView.Configuration(
                text: isSecureMode ? String.secureModeValueShort : amount,
                color: action.eventType.amountColor,
                textStyle: .label1,
                alignment: .right
            )
        }

        var subvalueViewConfiguration: TKListItemTextView.Configuration?
        if let subamount = action.subamount {
            subvalueViewConfiguration = TKListItemTextView.Configuration(
                text: isSecureMode ? String.secureModeValueShort : subamount,
                color: action.eventType.subamountColor,
                textStyle: .label1,
                alignment: .right
            )
        }

        var valueCaptionViewConfiguration: TKListItemTextView.Configuration?
        if let rightTopDescription = action.rightTopDescription {
            valueCaptionViewConfiguration = TKListItemTextView.Configuration(
                text: rightTopDescription,
                color: .Text.secondary,
                textStyle: .body2,
                alignment: .right,
                numberOfLines: 1
            )
        }

        let contentConfiguration = TKListItemContentView.Configuration(
            iconViewConfiguration: TKListItemIconView.Configuration(
                content: .image(
                    TKImageView.Model(
                        image: .image(icon),
                        tintColor: .Icon.secondary,
                        size: .auto,
                        corners: .circle
                    )
                ),
                alignment: .top,
                cornerRadius: 22,
                backgroundColor: .Background.contentTint,
                size: CGSize(width: 44, height: 44),
                badge: nil
            ),
            textContentViewConfiguration: TKListItemTextContentView.Configuration(
                titleViewConfiguration: TKListItemTitleView.Configuration(
                    title: accountEventModelActionContentProvider
                        .title(actionType: action.eventType, customName: action.customName),
                    caption: nil,
                    tags: [],
                    icon: nil
                ),
                captionViewsConfigurations: [
                    TKListItemTextView.Configuration(
                        text: action.leftTopDescription,
                        color: .Text.secondary,
                        textStyle: .body2,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    TKListItemTextView.Configuration(
                        text: action.status,
                        color: .Accent.orange,
                        textStyle: .body2,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                ],
                valueViewConfiguration: valueViewConfiguration,
                subvalueViewConfiguration: subvalueViewConfiguration,
                valueCaptionViewConfiguration: valueCaptionViewConfiguration,
                isCenterVertical: false
            )
        )

        var commentConfiguration: AccountEventCellActionView.CommentView.Configuration?
        if let comment = action.comment, action.eventType != .spam {
            commentConfiguration = AccountEventCellActionView.CommentView.Configuration(comment: comment)
        }

        var encryptedCommentConfiguration: AccountEventCellActionView.EncyptedCommentView.Model?
        if let encryptedComment = action.encryptedComment {
            switch encryptedComment {
            case let .encrypted(payload):
                encryptedCommentConfiguration = AccountEventCellActionView.EncyptedCommentView.Model(
                    encryptedText: payload.encryptedComment.cipherText,
                    action: {
                        encryptedCommentAction(payload)
                    }
                )
            case let .decrypted(decrypted):
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
            contentConfiguration: contentConfiguration,
            commentConfiguration: commentConfiguration,
            encryptedCommentConfiguration: encryptedCommentConfiguration,
            descriptionConfiguration: descriptionConfiguration,
            nftConfiguration: nftConfiguration,
            isInProgress: isInProgress
        )
    }

    private func mapFee(
        fee: String,
        feeConverted: String?,
        feeDescription: String?
    ) -> AccountEventCellActionView.Model {
        var captionViewsConfigurations = [TKListItemTextView.Configuration]()
        if let feeDescription {
            captionViewsConfigurations.append(
                TKListItemTextView.Configuration(
                    text: feeDescription,
                    color: .Text.secondary,
                    textStyle: .body2,
                    alignment: .left
                )
            )
        }

        var valueCaptionViewConfiguration: TKListItemTextView.Configuration?
        if let feeConverted {
            valueCaptionViewConfiguration = TKListItemTextView.Configuration(
                text: feeConverted,
                color: .Text.secondary,
                textStyle: .body2,
                alignment: .right
            )
        }

        let contentConfiguration = TKListItemContentView.Configuration(
            iconViewConfiguration: TKListItemIconView.Configuration(
                content: .image(
                    TKImageView.Model(
                        image: .image(.TKUIKit.Icons.Size28.ton),
                        tintColor: .Icon.secondary,
                        size: .auto,
                        corners: .none
                    )
                ),
                alignment: .top,
                cornerRadius: 22,
                backgroundColor: .Background.contentTint,
                size: CGSize(width: 44, height: 44),
                badge: nil
            ),
            textContentViewConfiguration: TKListItemTextContentView.Configuration(
                titleViewConfiguration: TKListItemTitleView.Configuration(
                    title: TKLocales.EventDetails.fee
                ),
                captionViewsConfigurations: captionViewsConfigurations,
                valueViewConfiguration: TKListItemTextView.Configuration(
                    text: fee,
                    color: .Text.primary,
                    textStyle: .label1,
                    alignment: .right
                ),
                valueCaptionViewConfiguration: valueCaptionViewConfiguration
            )
        )

        return AccountEventCellActionView.Model(
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
        case .purchase:
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
             .purchase,
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
