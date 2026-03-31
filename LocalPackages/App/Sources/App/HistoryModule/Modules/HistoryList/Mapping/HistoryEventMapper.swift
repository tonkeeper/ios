import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

struct HistoryEventMapper {
    let accountEventActionContentProvider: AccountEventActionContentProvider

    func mapEvent(
        _ event: AccountEventModel,
        isSecureMode: Bool,
        nftAction: @escaping (Address) -> Void,
        encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void,
        tapAction: @escaping (AccountEventDetailsEvent) -> Void
    ) -> HistoryCell.Model {
        return HistoryCell.Model(
            id: event.eventId,
            historyContentConfiguration: mapEventContentConfiguration(
                event,
                isSecureMode: isSecureMode,
                nftAction: nftAction,
                encryptedCommentAction: encryptedCommentAction,
                tapAction: tapAction
            )
        )
    }

    func mapEventContentConfiguration(
        _ event: AccountEventModel,
        isSecureMode: Bool,
        nftAction: @escaping (Address) -> Void,
        encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void,
        tapAction: @escaping (AccountEventDetailsEvent) -> Void
    ) -> HistoryCellContentView.Model {
        let actions = event.actions.enumerated().map { index, action in
            HistoryCellContentView.Model.Action(
                configuration: mapAction(
                    action,
                    eventAction: event.accountEvent.actions[index],
                    isInProgress: event.accountEvent.isInProgress,
                    isSecureMode: isSecureMode,
                    progress: event.accountEvent.progress,
                    nftAction: nftAction,
                    encryptedCommentAction: encryptedCommentAction
                ),
                action: {
                    tapAction(AccountEventDetailsEvent(accountEvent: event.accountEvent, action: event.accountEvent.actions[index]))
                }
            )
        }
        return HistoryCellContentView.Model(actions: actions)
    }

    func mapAction(
        _ action: AccountEventModel.Action,
        eventAction: AccountEventAction,
        isInProgress: Bool,
        isSecureMode: Bool,
        progress: Double?,
        nftAction: @escaping (Address) -> Void,
        encryptedCommentAction: @escaping (EncryptedCommentPayload) -> Void
    ) -> HistoryCellActionView.Model {
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
            let valueColor: UIColor
            if let progress, progress > 0, progress < 1 {
                valueColor = .Text.tertiary
            } else {
                valueColor = action.eventType.amountColor
            }
            valueViewConfiguration = TKListItemTextView.Configuration(
                text: isSecureMode ? String.secureModeValueShort : amount,
                color: valueColor,
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

        let title: String
        if let progress, progress > 0, progress < 1 {
            title = TKLocales.ActionTypes.pending
        } else {
            title = accountEventActionContentProvider.title(actionType: action.eventType, customName: action.customName)
        }

        var captionViewsConfigurations: [TKListItemTextView.Configuration] = [
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
        ]

        if isUnverifiedJetton(eventAction: eventAction) {
            captionViewsConfigurations.append(
                TKListItemTextView.Configuration(
                    text: TKLocales.Token.unverified,
                    color: .Accent.orange,
                    textStyle: .body2,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                )
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
                    title: title,
                    caption: nil,
                    tags: [],
                    icon: nil
                ),
                captionViewsConfigurations: captionViewsConfigurations,
                valueViewConfiguration: valueViewConfiguration,
                subvalueViewConfiguration: subvalueViewConfiguration,
                valueCaptionViewConfiguration: valueCaptionViewConfiguration,
                isCenterVertical: false
            )
        )

        var commentConfiguration: HistoryCellActionView.CommentView.Configuration?
        if let comment = action.comment, action.eventType != .spam {
            commentConfiguration = HistoryCellActionView.CommentView.Configuration(comment: comment)
        }

        var encryptedCommentConfiguration: HistoryCellActionView.EncyptedCommentView.Model?
        if let encryptedComment = action.encryptedComment {
            switch encryptedComment {
            case let .encrypted(payload):
                encryptedCommentConfiguration = HistoryCellActionView.EncyptedCommentView.Model(
                    encryptedText: payload.encryptedComment.cipherText,
                    action: {
                        encryptedCommentAction(payload)
                    }
                )
            case let .decrypted(decrypted):
                encryptedCommentConfiguration = HistoryCellActionView.EncyptedCommentView.Model(
                    decryptedText: decrypted
                )
            }
        }

        var descriptionConfiguration: HistoryCellActionView.CommentView.Configuration?
        if let description = action.description {
            descriptionConfiguration = HistoryCellActionView.CommentView.Configuration(comment: description)
        }

        var nftConfiguration: HistoryCellActionView.NFTView.Configuration?
        if let actionNft = action.nft {
            let imageViewModel = TKImageView.Model(
                image: TKImage.urlImage(actionNft.image),
                size: .size(CGSize(width: 64, height: 64))
            )

            nftConfiguration = HistoryCellActionView.NFTView.Configuration(
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

        let loaderState: HistoryCellLoaderView.State
        if let progress, progress > 0, progress < 1 {
            loaderState = .progress(progress)
        } else {
            loaderState = .idle
        }

        return HistoryCellActionView.Model(
            contentConfiguration: contentConfiguration,
            commentConfiguration: commentConfiguration,
            encryptedCommentConfiguration: encryptedCommentConfiguration,
            descriptionConfiguration: descriptionConfiguration,
            nftConfiguration: nftConfiguration,
            loaderState: loaderState
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
        case .purchase:
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

private extension HistoryEventMapper {
    func isUnverifiedJetton(eventAction: AccountEventAction) -> Bool {
        switch eventAction.type {
        case let .jettonTransfer(jettonTransfer):
            return jettonTransfer.jettonInfo.isUnverified
        case let .jettonBurn(jettonBurn):
            return jettonBurn.jettonInfo.isUnverified
        case let .jettonMint(jettonMint):
            return jettonMint.jettonInfo.isUnverified
        case let .jettonSwap(jettonSwap):
            return jettonSwap.jettonInfoIn?.isUnverified == true || jettonSwap.jettonInfoOut?.isUnverified == true
        default:
            return false
        }
    }
}
