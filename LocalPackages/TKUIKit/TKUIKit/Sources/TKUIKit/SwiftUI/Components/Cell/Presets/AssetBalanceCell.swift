import SwiftUI

public enum AssetBalanceCellConfig {
    case shimmer
    case content(AssetBalanceCellContent)
}

public struct AssetBalanceCellContent {
    public var symbol: String
    public var chainTag: String?
    public var assetImageSource: AssetAvatarViewImageSource
    public var amountText: String
    public var convertedAmountText: String?

    public init(
        symbol: String,
        chainTag: String? = nil,
        assetImageSource: AssetAvatarViewImageSource,
        amountText: String,
        convertedAmountText: String? = nil
    ) {
        self.symbol = symbol
        self.chainTag = chainTag
        self.assetImageSource = assetImageSource
        self.amountText = amountText
        self.convertedAmountText = convertedAmountText
    }
}

public struct AssetBalanceCell: View {
    public var config: AssetBalanceCellConfig

    private var freshness: BalanceFreshness = .actual

    public init(
        config: AssetBalanceCellConfig
    ) {
        self.config = config
    }

    public func balanceFreshness(_ freshness: BalanceFreshness) -> AssetBalanceCell {
        var cell = self
        cell.freshness = freshness
        return cell
    }

    public var body: some View {
        Cell {
            CellAssetLeading {
                leading
            }
        } center: {
            center
        }
    }

    @ViewBuilder
    private var center: some View {
        let rows = CellCenter {
            CellCenterPrimaryRow(
                config: primaryRowConfig
            )
        } secondaryRow: {
            CellCenterSecondaryRow(
                config: secondaryRowConfig
            )
        }

        if #available(iOS 17.0, *) {
            shimmering(
                rows
                    .contentTransition(.numericText())
                    .animation(Layout.amountAnimation, value: amounts)
            )
        } else {
            shimmering(rows)
        }
    }

    private func shimmering(_ content: some View) -> some View {
        content.tkTextShimmer(
            isActive: freshness == .pending,
            dimmingInto: .backgroundContent,
            appearsAfter: BalanceAmount.shimmerDelay
        )
    }

    private var amounts: [String] {
        guard case let .content(content) = config else {
            return []
        }
        return [content.amountText, content.convertedAmountText].compactMap { $0 }
    }

    @ViewBuilder
    private var leading: some View {
        switch config {
        case .shimmer:
            AssetAvatarView(
                imageSource: .shimmer
            )
        case let .content(content):
            AssetAvatarView(
                imageSource: content.assetImageSource
            )
        }
    }

    private var primaryRowConfig: CellCenterPrimaryRow.Config {
        switch config {
        case .shimmer:
            .shimmer()
        case let .content(content):
            .content(
                .init(
                    title: content.amountText,
                    tags: content.chainTag.map { tag in
                        [.tag(text: tag)]
                    }
                )
            )
        }
    }

    private var secondaryRowConfig: CellCenterSecondaryRow.Config {
        if let secondaryRowText {
            .content(
                CellCenterSecondaryRow.Content(
                    value: .init(
                        title: secondaryRowText
                    )
                )
            )
        } else {
            .shimmer()
        }
    }

    private var secondaryRowText: String? {
        switch config {
        case .shimmer:
            nil
        case let .content(config):
            config.convertedAmountText
        }
    }

    private enum Layout {
        static let amountAnimation: Animation = .easeInOut(duration: BalanceAmount.animationDuration)
    }
}
