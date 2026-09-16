import SwiftUI

public enum FeePickerCellConfig {
    case shimmer
    case content(FeePickerCellContent)
}

public struct FeePickerCellContent {
    public var leading: Leading
    public var title: String
    public var subtitle: String?
    public var isDisabled: Bool
    public var subtitleActionTitle: String?
    public var isSelected: Bool

    public init(
        leading: Leading,
        title: String,
        subtitle: String? = nil,
        isDisabled: Bool = false,
        subtitleActionTitle: String? = nil,
        isSelected: Bool = false
    ) {
        self.leading = leading
        self.title = title
        self.subtitle = subtitle
        self.isDisabled = isDisabled
        self.subtitleActionTitle = subtitleActionTitle
        self.isSelected = isSelected
    }
}

public extension FeePickerCellContent {
    enum Leading {
        case assetAvatar(imageSource: AssetAvatarViewImageSource)
        case icon(
            image: UIImage,
            tintColor: TKColor,
            backgroundColor: TKColor
        )
    }
}

public struct FeePickerCell: View {
    public var config: FeePickerCellConfig
    public var showsDivider: Bool
    public var action: (() -> Void)?

    public init(
        config: FeePickerCellConfig,
        showsDivider: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.config = config
        self.showsDivider = showsDivider
        self.action = action
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider,
                action: cellAction
            ),
            leading: {
                CellAssetLeading {
                    leadingView
                }
            },
            center: {
                centerView
            },
            trailing: {
                trailingView
            }
        )
        .allowsHitTesting(isHitTestingAllowed)
    }
}

private extension FeePickerCell {
    enum Layout {
        static let iconSize: CGFloat = 28
        static let iconContainerSize: CGFloat = 44
    }

    var cellAction: (() -> Void)? {
        switch config {
        case .shimmer:
            nil
        case .content:
            action
        }
    }

    var isHitTestingAllowed: Bool {
        switch config {
        case .shimmer:
            false
        case .content:
            true
        }
    }

    @ViewBuilder
    var leadingView: some View {
        switch config {
        case .shimmer:
            AssetAvatarView(imageSource: .shimmer)
        case let .content(content):
            switch content.leading {
            case let .assetAvatar(imageSource):
                AssetAvatarView(imageSource: imageSource)
                    .opacity(content.isDisabled ? 0.48 : 1)
            case let .icon(image, tintColor, backgroundColor):
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(
                            width: Layout.iconContainerSize,
                            height: Layout.iconContainerSize
                        )

                    Image(uiImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(tintColor)
                        .frame(
                            width: Layout.iconSize,
                            height: Layout.iconSize
                        )
                }
                .opacity(content.isDisabled ? 0.48 : 1)
            }
        }
    }

    @ViewBuilder
    var centerView: some View {
        switch config {
        case .shimmer:
            CellCenter {
                CellCenterPrimaryRow(
                    config: .shimmer()
                )
            } secondaryRow: {
                CellCenterSecondaryRow(
                    config: .shimmer()
                )
            }
        case let .content(content):
            if let subtitle = content.subtitle {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: primaryRowConfig(content)
                    )
                } secondaryRow: {
                    subtitleView(
                        subtitle: subtitle,
                        actionTitle: content.subtitleActionTitle
                    )
                }
            } else {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: primaryRowConfig(content)
                    )
                }
            }
        }
    }

    @ViewBuilder
    var trailingView: some View {
        switch config {
        case .shimmer:
            EmptyView()
        case let .content(content):
            if content.isSelected {
                CellTrailingAccessory(
                    config: .init(
                        color: .accentBlue,
                        icon: SwiftUI.Image.TKUIKit.Icons.Size28.donemarkOutline
                    )
                )
            }
        }
    }

    func primaryRowConfig(_ content: FeePickerCellContent) -> CellCenterPrimaryRow.Config {
        .content(
            .init(
                title: .init(
                    text: content.title,
                    color: content.isDisabled ? .textSecondary : .textPrimary
                )
            )
        )
    }

    @ViewBuilder
    func subtitleView(
        subtitle: String,
        actionTitle: String?
    ) -> some View {
        if let actionTitle {
            HStack(spacing: 0) {
                Text(subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(" · ")
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                Text(actionTitle)
                    .textStyle(.body2)
                    .foregroundStyle(.accentBlue)
            }
        } else {
            CellCenterSecondaryRow(
                config: .content(
                    .init(
                        value: .init(
                            title: subtitle
                        )
                    )
                )
            )
        }
    }
}
