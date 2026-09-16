import SwiftUI

public enum TradeAssetCellConfig: Sendable, Equatable {
    case shimmer
    case content(TradeAssetCellContent)
}

public struct TradeAssetCellContent: Sendable, Equatable {
    public var assetSymbol: String
    public var assetDisplayName: String
    public var chainTag: String?
    public var iconImageSource: AssetAvatarViewImageSource
    public var priceText: String
    public var changeText: ChangeText?
    public var showsVerificationCheckmark: Bool

    public init(
        assetSymbol: String,
        assetDisplayName: String,
        chainTag: String?,
        iconImageSource: AssetAvatarViewImageSource,
        priceText: String,
        changeText: ChangeText?,
        showsVerificationCheckmark: Bool = false
    ) {
        self.assetSymbol = assetSymbol
        self.assetDisplayName = assetDisplayName
        self.chainTag = chainTag
        self.iconImageSource = iconImageSource
        self.priceText = priceText
        self.changeText = changeText
        self.showsVerificationCheckmark = showsVerificationCheckmark
    }
}

public extension TradeAssetCellContent {
    struct ChangeText: Sendable, Equatable {
        public var title: String
        public var positive: Bool

        public init(
            title: String,
            positive: Bool
        ) {
            self.title = title
            self.positive = positive
        }
    }
}

public struct TradeAssetCell: View {
    public var config: TradeAssetCellConfig
    public var onTap: () -> Void

    public init(
        config: TradeAssetCellConfig,
        onTap: @escaping () -> Void = {}
    ) {
        self.config = config
        self.onTap = onTap
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                action: onTap
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: imageSource
                    )
                }
            },
            center: {
                CellCenter(
                    primaryRow: CellCenterPrimaryRow(
                        config: primaryRowConfig
                    ),
                    secondaryRow: CellCenterSecondaryRow(
                        config: secondaryRowConfig
                    )
                )
            }
        )
    }
}

// MARK: - Leading

extension TradeAssetCell {
    private var imageSource: AssetAvatarViewImageSource {
        switch config {
        case .shimmer:
            .shimmer
        case let .content(content):
            content.iconImageSource
        }
    }
}

// MARK: - Primary Row

extension TradeAssetCell {
    private var primaryRowConfig: CellCenterPrimaryRow.Config {
        switch config {
        case .shimmer:
            .shimmer()
        case let .content(content):
            .content(
                .init(
                    title: content.assetSymbol,
                    tags: content.chainTag.map { tag in
                        [.tag(text: tag)]
                    },
                    statusIcons: content.showsVerificationCheckmark ? [.verificationCheckmark] : nil,
                    value: .init(
                        title: content.priceText
                    )
                )
            )
        }
    }
}

private extension CellCenterPrimaryRow.StatusIcon {
    static var verificationCheckmark: Self {
        .init(
            image: .TKUIKit.Icons.Size16.verification,
            color: .accentBlue,
            size: 16
        )
    }
}

// MARK: - Secondary Row

extension TradeAssetCell {
    private var secondaryRowConfig: CellCenterSecondaryRow.Config {
        switch config {
        case .shimmer:
            .shimmer()
        case let .content(content):
            .content(
                CellCenterSecondaryRow.Content(
                    value: .init(
                        title: content.assetDisplayName
                    ),
                    accessory: content.changeText
                        .map { changeText in
                            CellCenterSecondaryRow.AccessoryConfig(
                                title: changeText.title,
                                color: changeText.positive
                                    ? .accentGreen
                                    : .accentRed
                            )
                        }
                )
            )
        }
    }
}
