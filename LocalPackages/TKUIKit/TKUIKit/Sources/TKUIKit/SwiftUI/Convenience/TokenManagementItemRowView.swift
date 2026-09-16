import SwiftUI
import UIKit

public struct TokenManagementCategory: Identifiable {
    public let id: String
    public let title: String
    public let icon: UIImage?

    public init(
        id: String,
        title: String,
        icon: UIImage? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

public struct TokenManagementItem: Identifiable {
    public let id: String
    public let symbol: String
    public let title: String
    public let chainTag: String?
    public let chainIcon: UIImage?
    public let imageURL: URL?
    public let avatarImageSource: AssetAvatarViewImageSource
    public let subtitle: String
    public let subtitleColor: TKColor

    public init(
        id: String,
        symbol: String,
        title: String,
        chainTag: String? = nil,
        chainIcon: UIImage? = nil,
        imageURL: URL? = nil,
        avatarImageSource: AssetAvatarViewImageSource? = nil,
        subtitle: String,
        subtitleColor: TKColor = .textSecondary
    ) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.chainTag = chainTag
        self.chainIcon = chainIcon
        self.imageURL = imageURL
        self.avatarImageSource = avatarImageSource ?? {
            guard let imageURL else {
                return .image(nil, chainIcon: chainIcon)
            }
            return .url(imageURL, chainIcon: chainIcon)
        }()
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
    }
}

struct TokenManagementContentView: View {
    let items: [TokenManagementItem]
    let hiddenItemIDs: Set<String>
    let onToggleVisibility: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                TokenManagementItemRowView(
                    item: item,
                    isHidden: hiddenItemIDs.contains(item.id),
                    showDivider: index < items.count - 1,
                    onToggleVisibility: {
                        onToggleVisibility(item.id)
                    }
                )
            }
        }
        .asCellsGroup(
            config: .init(horizontalPadding: 0)
        )
    }
}

public enum TokenManagementItemRowConfig {
    case shimmer
    case content(
        item: TokenManagementItem,
        isHidden: Bool,
        onToggleVisibility: () -> Void
    )
}

public struct TokenManagementItemRowView: View {
    let config: TokenManagementItemRowConfig
    let showDivider: Bool

    public init(
        config: TokenManagementItemRowConfig,
        showDivider: Bool
    ) {
        self.config = config
        self.showDivider = showDivider
    }

    public init(
        item: TokenManagementItem,
        isHidden: Bool,
        showDivider: Bool,
        onToggleVisibility: @escaping () -> Void
    ) {
        self.init(
            config: .content(
                item: item,
                isHidden: isHidden,
                onToggleVisibility: onToggleVisibility
            ),
            showDivider: showDivider
        )
    }

    public var body: some View {
        Cell(
            config: .init(
                style: .grouped,
                showsDivider: showDivider,
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
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private extension TokenManagementItemRowView {
    var cellAction: (() -> Void)? {
        switch config {
        case .shimmer:
            return nil
        case let .content(_, _, onToggleVisibility):
            return onToggleVisibility
        }
    }

    var isHitTestingAllowed: Bool {
        switch config {
        case .shimmer:
            return false
        case .content:
            return true
        }
    }

    var accessibilityIdentifier: String {
        switch config {
        case .shimmer:
            "token_management_item_shimmer"
        case let .content(item, _, _):
            "token_management_item_\(item.symbol)"
        }
    }

    @ViewBuilder
    var leadingView: some View {
        switch config {
        case .shimmer:
            AssetAvatarView(imageSource: .shimmer)
        case let .content(item, _, _):
            AssetAvatarView(imageSource: item.avatarImageSource)
        }
    }

    @ViewBuilder
    var centerView: some View {
        switch config {
        case .shimmer:
            CellCenter(
                primaryRow: CellCenterPrimaryRow(config: .shimmer()),
                secondaryRow: CellCenterSecondaryRow(config: .shimmer())
            )
        case let .content(item, _, _):
            CellCenter(
                primaryRow: CellCenterPrimaryRow(
                    config: .content(
                        .init(
                            title: item.title,
                            tags: item.chainTag.map { tag in
                                [.tag(text: tag)]
                            }
                        )
                    )
                ),
                secondaryRow: CellCenterSecondaryRow(
                    config: .content(
                        .init(
                            value: .init(
                                title: item.subtitle,
                                textColor: item.subtitleColor
                            )
                        )
                    )
                )
            )
        }
    }

    @ViewBuilder
    var trailingView: some View {
        switch config {
        case .shimmer:
            ShimmerSwiftUIView()
                .frame(width: 28, height: 28)
        case let .content(_, isHidden, _):
            CellTrailingAccessory(
                config: .init(
                    color: isHidden
                        ? .iconTertiary
                        : .accentBlue,
                    icon: .init(
                        uiImage: isHidden
                            ? .TKUIKit.Icons.Size28.eyeClosedOutline
                            : .TKUIKit.Icons.Size28.eyeOutline
                    ),
                    iconSize: 28
                )
            )
        }
    }
}

#Preview {
    TokenManagementContentView(
        items: [
            .init(
                id: "TON",
                symbol: "TON",
                title: "TON",
                chainIcon: UIImage.TKUIKit.Icons.Size20.tonChain,
                subtitle: "2 345 TON · $ 3 456"
            ),
            .init(
                id: "USDT",
                symbol: "USD₮",
                title: "USD₮",
                chainTag: "TRON",
                chainIcon: UIImage.TKUIKit.Icons.Size20.trxChain,
                subtitle: "906 USD₮ · $ 902"
            ),
        ],
        hiddenItemIDs: ["USDT"],
        onToggleVisibility: { _ in }
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
    .background(TKPreview.palette.background.page)
    .debugPreview(background: .page)
}
