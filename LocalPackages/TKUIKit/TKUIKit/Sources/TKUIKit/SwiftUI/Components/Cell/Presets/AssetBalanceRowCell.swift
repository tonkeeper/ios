import SwiftUI

public enum AssetBalanceRowCellConfig {
    case shimmer
    case content(AssetBalanceRowCellContent)
}

public struct AssetBalanceRowCellContent: Identifiable, Equatable {
    public struct Delta: Equatable {
        public let text: String
        public let isPositive: Bool

        public init(
            text: String,
            isPositive: Bool
        ) {
            self.text = text
            self.isPositive = isPositive
        }
    }

    public enum DisplayMode: Equatable {
        case includingDiffs(
            balance: String,
            price: String,
            delta: Delta?,
            fiat: String,
            showsPin: Bool,
            priceColor: TKColor
        )
        case includingMarketData(
            marketCap: String,
            price: String,
            change: Delta?,
            showsPin: Bool
        )
        case includingSelection(
            balance: String,
            fiat: String,
            showsPin: Bool
        )
        case rampAsset(
            subtitle: String
        )
    }

    public let id: String
    public let title: String
    public let badge: String?
    public let apy: String?
    public let displayMode: DisplayMode
    public let avatarImageSource: AssetAvatarViewImageSource
    public let showsVerificationCheckmark: Bool
    public let comment: String?
    public let accessibilityIdentifier: String?

    public init(
        id: String,
        title: String,
        badge: String?,
        apy: String? = nil,
        displayMode: DisplayMode,
        avatarImageSource: AssetAvatarViewImageSource,
        showsVerificationCheckmark: Bool = false,
        comment: String? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.badge = badge
        self.apy = apy
        self.displayMode = displayMode
        self.avatarImageSource = avatarImageSource
        self.showsVerificationCheckmark = showsVerificationCheckmark
        self.comment = comment
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

public struct AssetBalanceRowCell: View {
    public let config: AssetBalanceRowCellConfig
    public let showsDivider: Bool
    public let action: (() -> Void)?
    public let commentAction: (() -> Void)?

    public init(
        config: AssetBalanceRowCellConfig,
        showsDivider: Bool = false,
        action: (() -> Void)? = nil,
        commentAction: (() -> Void)? = nil
    ) {
        self.config = config
        self.showsDivider = showsDivider
        self.action = action
        self.commentAction = commentAction
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .grouped,
                showsDivider: showsDivider,
                verticalAlignment: comment == nil ? .center : .top,
                action: action
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(imageSource: avatarImageSource)
                }
            },
            center: {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(
                            config: primaryRowConfig
                        )
                    },
                    secondaryRow: {
                        VStack(alignment: .leading, spacing: 0) {
                            CellCenterSecondaryRow(
                                config: secondaryRowConfig
                            )
                            if let comment {
                                AssetBalanceRowCommentView(
                                    text: comment,
                                    action: commentAction
                                )
                                .padding(.top, Layout.commentTopSpacing)
                            }
                        }
                    }
                )
            },
            trailing: {
                if showsTrailingAccessory {
                    CellTrailingAccessory(
                        config: .init(
                            color: .accentBlue,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size28.donemarkOutline,
                            iconSize: 28
                        )
                    )
                } else {
                    EmptyView()
                }
            }
        )
        .accessibilityIdentifier(content?.accessibilityIdentifier)
    }
}

private extension AssetBalanceRowCell {
    enum Layout {
        static let commentTopSpacing: CGFloat = 8
    }

    var content: AssetBalanceRowCellContent? {
        if case let .content(content) = config {
            return content
        }
        return nil
    }

    var comment: String? {
        content?.comment
    }

    var avatarImageSource: AssetAvatarViewImageSource {
        switch config {
        case .shimmer:
            return .shimmer
        case let .content(content):
            return content.avatarImageSource
        }
    }

    var primaryRowConfig: CellCenterPrimaryRow.Config {
        switch config {
        case .shimmer:
            return .shimmer()
        case let .content(content):
            return .content(primaryRowContent(content))
        }
    }

    func primaryRowContent(_ content: AssetBalanceRowCellContent) -> CellCenterPrimaryRow.Content {
        let tags = makeTags(content)

        switch content.displayMode {
        case let .includingDiffs(balance, _, _, _, showsPin, _):
            return .init(
                title: content.title,
                tags: tags,
                statusIcons: statusIcons(content: content, showsPin: showsPin),
                value: .init(title: balance)
            )
        case let .includingMarketData(_, price, _, showsPin):
            return .init(
                title: content.title,
                tags: tags,
                statusIcons: statusIcons(content: content, showsPin: showsPin),
                value: .init(title: price)
            )
        case let .includingSelection(_, _, showsPin):
            return .init(
                title: content.title,
                tags: tags,
                statusIcons: statusIcons(content: content, showsPin: showsPin)
            )
        case .rampAsset:
            return .init(
                title: content.title,
                tags: tags,
                statusIcons: statusIcons(content: content, showsPin: false)
            )
        }
    }

    func makeTags(_ content: AssetBalanceRowCellContent) -> [TKTagSwiftUIViewConfig]? {
        var tags = [TKTagSwiftUIViewConfig]()
        if let badge = content.badge {
            tags.append(.tag(text: badge))
        }
        if let apy = content.apy {
            tags.append(.accentTag(text: apy, accent: .accentGreen))
        }
        return tags.isEmpty ? nil : tags
    }

    func statusIcons(
        content: AssetBalanceRowCellContent,
        showsPin: Bool
    ) -> [CellCenterPrimaryRow.StatusIcon] {
        var icons = [CellCenterPrimaryRow.StatusIcon]()
        if content.showsVerificationCheckmark {
            icons.append(.verificationCheckmark)
        }
        if showsPin {
            icons.append(.pin)
        }
        return icons
    }

    var secondaryRowConfig: CellCenterSecondaryRow.Config {
        switch config {
        case .shimmer:
            return .shimmer()
        case let .content(content):
            return .content(secondaryRowContent(content))
        }
    }

    func secondaryRowContent(_ content: AssetBalanceRowCellContent) -> CellCenterSecondaryRow.Content {
        switch content.displayMode {
        case let .includingDiffs(_, price, delta, fiat, _, priceColor):
            return .init(
                value: .init(
                    title: price,
                    textColor: priceColor
                ),
                delta: delta.map {
                    .init(text: $0.text, isPositive: $0.isPositive)
                },
                accessory: .init(
                    title: fiat
                )
            )
        case let .includingMarketData(marketCap, _, change, _):
            return .init(
                value: .init(title: marketCap),
                accessory: change.map { change in
                    .init(
                        title: change.text,
                        color: change.isPositive ? .accentGreen : .accentRed
                    )
                }
            )
        case let .includingSelection(balance, fiat, _):
            return .init(
                value: .init(title: [balance, fiat].joined(separator: " · "))
            )
        case let .rampAsset(subtitle):
            return .init(
                value: .init(title: subtitle)
            )
        }
    }

    var showsTrailingAccessory: Bool {
        guard let displayMode = content?.displayMode else {
            return false
        }

        switch displayMode {
        case .includingDiffs,
             .includingMarketData:
            return false
        case let .includingSelection(_, _, showsPin):
            return showsPin
        case .rampAsset:
            return false
        }
    }
}

private struct AssetBalanceRowCommentView: View {
    let text: String
    let action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                bubble
            }
            .buttonStyle(TKTapAnimationButtonStyle())
        } else {
            bubble
        }
    }

    private var bubble: some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.bubbleForeground)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.topPadding)
            .padding(.bottom, Layout.bottomPadding)
            .background {
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(.bubbleBackground)
            }
    }
}

private extension AssetBalanceRowCommentView {
    enum Layout {
        static let cornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let topPadding: CGFloat = 6
        static let bottomPadding: CGFloat = 7
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

    static var pin: Self {
        .init(image: .TKUIKit.Icons.Size12.pin, size: 12)
    }
}
