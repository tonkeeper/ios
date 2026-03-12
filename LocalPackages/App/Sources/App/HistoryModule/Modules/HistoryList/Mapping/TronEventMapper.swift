import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

struct TronEventMapper {
    private let dateFormatter: DateFormatter
    private let amountFormatter: AmountFormatter

    init(
        dateFormatter: DateFormatter,
        amountFormatter: AmountFormatter
    ) {
        self.dateFormatter = dateFormatter
        self.amountFormatter = amountFormatter
    }

    func mapEvent(
        _ event: TronTransaction,
        owner: TronSwift.Address,
        dateFormat: String,
        tapAction: @escaping () -> Void
    ) -> HistoryCell.Model {
        let eventType = event.getTransactionType(address: owner)
        let icon: UIImage
        switch eventType {
        case .send:
            icon = .Resources.Icons.Size28.trayArrowUp
        case .receive:
            icon = .Resources.Icons.Size28.trayArrowDown
        }
        let title: String = {
            guard !event.isPending else { return TKLocales.ActionTypes.pending }

            return switch eventType {
            case .send:
                TKLocales.ActionTypes.sent
            case .receive:
                TKLocales.ActionTypes.received
            }
        }()

        let subtitle: String = {
            switch eventType {
            case .send:
                event.toAccount.shortBase58
            case .receive:
                event.fromAccount.shortBase58
            }
        }()

        dateFormatter.dateFormat = dateFormat
        let date = dateFormatter
            .string(from: Date(timeIntervalSince1970: TimeInterval(event.timestamp)))
            .withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .right,
                lineBreakMode: .byWordWrapping
            )

        let status: NSAttributedString? = {
            guard event.isFailed else { return nil }
            return "Failed".withTextStyle(
                .body2,
                color: .Accent.orange,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
        }()

        let value: NSAttributedString = {
            let amountType: AccountEventActionAmountMapperActionType
            let color: UIColor
            switch eventType {
            case .send:
                amountType = .outcome
                color = event.isPending ? .Text.tertiary : .Text.primary
            case .receive:
                amountType = .income
                color = event.isPending ? .Text.tertiary : .Accent.green
            }
            let amount = amountFormatter.format(
                amount: event.amount,
                fractionDigits: TronSwift.USDT.fractionDigits,
                accessory: .symbol(TronSwift.USDT.symbol),
                isNegative: amountType == .outcome
            )

            return amount.withTextStyle(
                .label1,
                color: color,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
        }()

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
                    tags: [.tag(text: TronSwift.USDT.tag)],
                    icon: nil
                ),
                captionViewsConfigurations: [
                    TKListItemTextView.Configuration(
                        text: subtitle,
                        color: .Text.secondary,
                        textStyle: .body2,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    TKListItemTextView.Configuration(
                        text: status
                    ),
                ],
                valueViewConfiguration: TKListItemTextView.Configuration(
                    text: value
                ),
                valueCaptionViewConfiguration: TKListItemTextView.Configuration(
                    text: date
                ),
                isCenterVertical: false
            )
        )

        let action = HistoryCellContentView.Model.Action(
            configuration: HistoryCellActionView.Model(
                contentConfiguration: contentConfiguration,
                loaderState: event.isPending ? .infinite : .idle
            ),
            action: {
                tapAction()
            }
        )

        return HistoryCell.Model(
            id: event.txID,
            historyContentConfiguration: HistoryCellContentView.Model(
                actions: [action]
            )
        )
    }
}
