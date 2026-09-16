import SwiftUI

public struct DAppListCellContent {
    public var name: String
    public var caption: String?
    public var image: AssetAvatarViewImageSource
    public var sourceAccent: Color?
    public var showSeparator: Bool

    public init(
        name: String,
        caption: String?,
        image: AssetAvatarViewImageSource,
        sourceAccent: Color? = nil,
        showSeparator: Bool
    ) {
        self.name = name
        self.caption = caption
        self.image = image
        self.sourceAccent = sourceAccent
        self.showSeparator = showSeparator
    }
}

public struct DAppListCell: View {
    private let content: DAppListCellContent
    private let action: (() -> Void)?

    public init(
        content: DAppListCellContent,
        action: (() -> Void)? = nil
    ) {
        self.content = content
        self.action = action
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                showsDivider: content.showSeparator,
                action: action
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: content.image,
                        size: .small,
                        shape: .rectangle(cornerRadius: Layout.avatarCornerRadius),
                        chainIconBackgroundColor: content.sourceAccent
                    )
                }
            },
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(
                                title: CellCenterPrimaryRow.TitleConfig(
                                    text: content.name,
                                    style: .label2
                                )
                            )
                        )
                    )
                } secondaryRow: {
                    if let caption = content.caption, !caption.isEmpty {
                        CellCenterSecondaryRow(
                            config: .content(
                                CellCenterSecondaryRow.Content(
                                    value: CellCenterSecondaryRow.ValueConfig(
                                        title: caption,
                                        textStyle: .body3Alternate,
                                        lineLimit: Layout.captionLineLimit
                                    )
                                )
                            )
                        )
                    } else {
                        EmptyView()
                    }
                } contentInsets: { insets in
                    insets.top = Layout.contentTopInset
                    insets.bottom = Layout.contentBottomInset
                    insets.leading = Layout.contentLeadingInset
                }
            },
            trailing: {
                CellTrailingAccessory(
                    config: CellTrailingAccessory.Config(
                        color: .iconTertiary,
                        icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                        iconSize: Layout.trailingIconSize
                    )
                )
            }
        )
        .frame(height: Layout.height)
    }
}

private extension DAppListCell {
    enum Layout {
        static let avatarCornerRadius: CGFloat = 12
        static let captionLineLimit = 2
        static let contentTopInset: CGFloat = 1
        static let contentBottomInset: CGFloat = 0
        static let contentLeadingInset: CGFloat = 12
        static let trailingIconSize: CGFloat = 16
        static let height: CGFloat = 76
    }
}

#Preview {
    VStack(spacing: 0) {
        DAppListCell(
            content: DAppListCellContent(
                name: "Aave",
                caption: "Fast fiat-to-crypto checkout",
                image: .image(.TKUIKit.Icons.Size44.tonWhalesLogo),
                showSeparator: true
            )
        )
        DAppListCell(
            content: DAppListCellContent(
                name: "Compound",
                caption: "Instantly buy TON, BTC with a credit card",
                image: .image(.TKUIKit.Icons.Size44.tonStakersLogo, chainIcon: .TKUIKit.Icons.Size20.ethChain),
                sourceAccent: TKPreview.palette.background.content,
                showSeparator: false
            )
        )
    }
    .asCellsGroup()
    .debugPreview(background: .page)
}
