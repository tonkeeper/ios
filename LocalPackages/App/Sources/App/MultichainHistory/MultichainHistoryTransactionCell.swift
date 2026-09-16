import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct MultichainHistoryTransactionCell: View {
    let item: MultichainHistoryActivityItem
    let showsDivider: Bool
    let onTap: () -> Void

    var body: some View {
        TransactionCell(
            config: .content(
                TransactionCellContent(
                    icon: item.transactionIcon,
                    title: item.title,
                    subtitle: TransactionCellContent.Subtitle(
                        text: item.subtitle ?? "",
                        style: .primary
                    ),
                    amount: item.transactionAmount,
                    accessory: item.transactionAccessory,
                    details: item.transactionDetails,
                    nftPreview: item.transactionNftPreview,
                    messages: item.transactionMessages,
                    showsDivider: showsDivider
                )
            ),
            onTap: onTap,
            onTapNft: { _ in onTap() }
        )
    }
}

extension MultichainHistoryActivityItem {
    var transactionIcon: TransactionCellContent.Icon {
        let isStakingProvider = MultichainHistoryStakingProvider(activity: activity) != nil
        let renderingMode: TransactionCellContent.Icon.RenderingMode = isStakingProvider ? .original : .template

        switch status {
        case .pending:
            return TransactionCellContent.Icon(
                image: icon,
                renderingMode: renderingMode,
                badge: .loader
            )
        case .failed, .dropped:
            if isStakingProvider {
                return TransactionCellContent.Icon(
                    image: icon,
                    renderingMode: renderingMode
                )
            }
            return .failed
        case .confirmed:
            return TransactionCellContent.Icon(
                image: icon,
                renderingMode: renderingMode
            )
        }
    }

    var transactionAmount: TransactionCellContent.Amount {
        guard let primaryAmount else {
            return TransactionCellContent.Amount(
                title: "-",
                style: .tertiary
            )
        }

        return TransactionCellContent.Amount(
            spans: primaryAmount.transactionAmountSpans,
            style: primaryAmount.transactionAmountStyle
        )
    }

    var transactionAccessory: TransactionCellContent.Accessory {
        guard let secondaryAmount else {
            guard !showsStatusDetails else {
                return .stub
            }

            return TransactionCellContent.Accessory(text: time)
        }

        return TransactionCellContent.Accessory(
            spans: secondaryAmount.transactionAccessorySpans,
            textStyle: .label1,
            color: secondaryAmount.transactionAccessoryColor
        )
    }

    var transactionDetails: TransactionCellContent.Details? {
        let title = detailsTitle
        let accessory = transactionDetailsAccessory

        guard title != nil || accessory != nil else {
            return nil
        }

        return TransactionCellContent.Details(
            title: title,
            accessory: accessory
        )
    }

    var detailsTitle: TransactionCellContent.DetailsTitle? {
        if showsStatusDetails {
            return TransactionCellContent.DetailsTitle(
                text: TKLocales.State.failed,
                color: .accentOrange
            )
        }

        if activity.isSpam {
            return TransactionCellContent.DetailsTitle(
                text: TKLocales.History.Tab.spam,
                color: .textTertiary
            )
        }

        return nil
    }

    var transactionDetailsAccessory: TransactionCellContent.DetailsAccessory? {
        guard secondaryAmount != nil || showsStatusDetails else {
            return nil
        }

        return TransactionCellContent.DetailsAccessory(
            text: time
        )
    }

    var showsStatusDetails: Bool {
        switch status {
        case .failed, .dropped:
            return true
        case .pending, .confirmed:
            return false
        }
    }

    var transactionNftPreview: TransactionCellContent.NftPreview? {
        guard let nft else {
            return nil
        }

        return TransactionCellContent.NftPreview(
            id: nft.id,
            imageSource: .url(nft.imageURL),
            title: nft.name,
            subtitle: nft.collectionName,
            isVerified: nft.isVerified
        )
    }

    var transactionMessages: [TransactionCellContent.Message] {
        guard !activity.isSpam,
              let comment = comment?.trimmingCharacters(in: .whitespacesAndNewlines),
              !comment.isEmpty
        else {
            return []
        }
        return [TransactionCellContent.Message(id: "comment", text: comment)]
    }
}

private extension MultichainHistoryActivityItem.Amount {
    var transactionAmountSpans: [TransactionCellContent.Amount.Span] {
        var spans = [TransactionCellContent.Amount.Span(text: text)]
        if let chainTitle {
            spans.append(.init(text: " \(chainTitle)", color: .textSecondary))
        }
        return spans
    }

    var transactionAccessorySpans: [TransactionCellContent.Accessory.Span] {
        var spans = [TransactionCellContent.Accessory.Span(text: text)]
        if let chainTitle {
            spans.append(.init(text: " \(chainTitle)", color: .textSecondary))
        }
        return spans
    }

    var transactionAmountStyle: TransactionCellContent.AmountStyle {
        switch style {
        case .primary:
            return .primary
        case .positive:
            return .positive
        case .negative:
            return .primary
        }
    }

    var transactionAccessoryColor: TKColor {
        switch style {
        case .positive:
            return .accentGreen
        case .primary, .negative:
            return .textPrimary
        }
    }
}
