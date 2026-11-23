import SwiftUI
import TKUIKit

public struct MoonPayPaymentMethodViewState {
    public var title: String
    /// "via MoonPay" under the title; it opens the provider sheet when there is another to pick.
    public var provider: Provider?
    public var sections: [Section]
    public var cryptoSection: CryptoSection?
    /// Another provider's methods are loading: skeleton rows stand in for the sections.
    public var isLoading: Bool

    public struct Provider {
        public var caption: String
        public var name: String
        public var isSwitchable: Bool

        public init(caption: String, name: String, isSwitchable: Bool) {
            self.caption = caption
            self.name = name
            self.isSwitchable = isSwitchable
        }
    }

    public struct CryptoSection {
        public var title: String
        public var content: SetupCellContent

        public init(title: String, content: SetupCellContent) {
            self.title = title
            self.content = content
        }
    }

    public struct Section: Identifiable {
        public var id: String
        public var title: String
        public var rows: [Row]

        public init(id: String, title: String, rows: [Row]) {
            self.id = id
            self.title = title
            self.rows = rows
        }
    }

    public struct Row: Identifiable {
        public var id: String
        public var title: String
        public var subtitle: String
        public var iconURL: URL?
        public var savedCard: MoonPaySavedCardIcon?
        public var badge: String?
        public var subtitleSuffix: SubtitleSuffix?
        public var isEnabled: Bool
        public var trailing: Trailing
        /// Shown behind the row's "⋯" button; no button when empty.
        public var menu: [MenuItem]

        public init(
            id: String,
            title: String,
            subtitle: String,
            iconURL: URL?,
            savedCard: MoonPaySavedCardIcon? = nil,
            badge: String? = nil,
            subtitleSuffix: SubtitleSuffix? = nil,
            isEnabled: Bool = true,
            trailing: Trailing,
            menu: [MenuItem] = []
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.iconURL = iconURL
            self.savedCard = savedCard
            self.badge = badge
            self.subtitleSuffix = subtitleSuffix
            self.isEnabled = isEnabled
            self.trailing = trailing
            self.menu = menu
        }
    }

    public struct MenuItem: Identifiable {
        public var id: String
        public var title: String
        public var icon: UIImage

        public init(id: String, title: String, icon: UIImage) {
            self.id = id
            self.title = title
            self.icon = icon
        }
    }

    public struct SubtitleSuffix: Equatable {
        public enum Style: Equatable {
            case neutral
            case warning
            case error
        }

        public var text: String
        public var style: Style

        public init(text: String, style: Style) {
            self.text = text
            self.style = style
        }

        var color: TKColor {
            switch style {
            case .neutral: .textSecondary
            case .warning: .accentOrange
            case .error: .accentRed
            }
        }
    }

    public enum Trailing: Equatable {
        case checkmark
        case none
    }

    public init(
        title: String,
        provider: Provider? = nil,
        sections: [Section],
        cryptoSection: CryptoSection? = nil,
        isLoading: Bool = false
    ) {
        self.title = title
        self.provider = provider
        self.sections = sections
        self.cryptoSection = cryptoSection
        self.isLoading = isLoading
    }
}

public struct MoonPayPaymentMethodView: View {
    private let state: MoonPayPaymentMethodViewState
    private let onSelect: (String) -> Void
    private let onMenuAction: (_ rowID: String, _ itemID: String) -> Void
    private let onCryptoDeposit: () -> Void
    private let onProviderTap: () -> Void
    private let onBack: () -> Void
    private let onClose: () -> Void

    public init(
        state: MoonPayPaymentMethodViewState,
        onSelect: @escaping (String) -> Void,
        onMenuAction: @escaping (_ rowID: String, _ itemID: String) -> Void = { _, _ in },
        onCryptoDeposit: @escaping () -> Void = {},
        onProviderTap: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.onSelect = onSelect
        self.onMenuAction = onMenuAction
        self.onCryptoDeposit = onCryptoDeposit
        self.onProviderTap = onProviderTap
        self.onBack = onBack
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    leftIcon: .back(onTap: { _ in onBack() }),
                    title: DefaultModalCardHeader.Title(text: state.title),
                    subtitle: providerSubtitle,
                    rightIcon: .close(onTap: { _ in onClose() }),
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if state.isLoading {
                        skeletonSection
                    } else {
                        ForEach(state.sections) { section in
                            sectionView(section)
                        }
                    }
                    if let crypto = state.cryptoSection {
                        cryptoSectionView(crypto)
                    }
                }
                .padding(.bottom, Layout.bottomPadding)
            }
            .tkImmediateButtonPresses()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }

    private var providerSubtitle: DefaultModalCardHeader.Subtitle? {
        guard let provider = state.provider else { return nil }
        return DefaultModalCardHeader.Subtitle(
            text: provider.caption,
            color: .textSecondary,
            accentText: provider.name,
            accentColor: provider.isSwitchable ? .accentBlue : .textSecondary,
            icon: provider.isSwitchable
                ? .init(image: .TKUIKit.Icons.Size16.switch, size: Layout.providerIconSize, topPadding: Layout.providerIconTop)
                : nil,
            onTap: provider.isSwitchable ? onProviderTap : nil
        )
    }

    private func sectionView(_ section: MoonPayPaymentMethodViewState.Section) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(section.title)

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, showsDivider: index < section.rows.count - 1)
                }
            }
            .asCellsGroup()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        ListTitleView(config: .text(title))
            .padding(.horizontal, Layout.sectionTitleInset)
    }

    private var skeletonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .shimmer(hasAccessory: false))
                .padding(.horizontal, Layout.sectionTitleInset)

            VStack(spacing: 0) {
                ForEach(0 ..< Layout.skeletonRowCount, id: \.self) { index in
                    skeletonRow(showsDivider: index < Layout.skeletonRowCount - 1)
                }
            }
            .asCellsGroup()
        }
        .accessibilityHidden(true)
    }

    private func skeletonRow(showsDivider: Bool) -> some View {
        HStack(spacing: Layout.skeletonSpacing) {
            ShimmerSwiftUIView(config: Self.skeletonConfig)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
            VStack(alignment: .leading, spacing: 0) {
                skeletonLine(width: Layout.skeletonTitleWidth, style: .label1)
                skeletonLine(width: Layout.skeletonSubtitleWidth, style: .body2)
            }
            Spacer(minLength: 0)
        }
        .padding(Layout.skeletonPadding)
        .overlay(alignment: .bottom) {
            if showsDivider {
                TKColor.separatorCommon
                    .frame(height: Layout.dividerHeight)
                    .padding(.leading, Layout.dividerInset)
            }
        }
    }

    private func skeletonLine(width: CGFloat, style: TKTextStyle) -> some View {
        Text(" ")
            .textStyle(style)
            .hidden()
            .overlay(alignment: .leading) {
                ShimmerSwiftUIView(config: Self.skeletonConfig)
                    .frame(width: width, height: Layout.skeletonLineHeight)
            }
    }

    private static var skeletonConfig: ShimmerSwiftUIView.Config {
        ShimmerSwiftUIView.Config(color: .backgroundContentTint, cornerRadius: .capsule)
    }

    private func cryptoSectionView(_ section: MoonPayPaymentMethodViewState.CryptoSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(section.title)

            SetupCell(content: section.content, onTap: onCryptoDeposit)
                .asCellsGroup()
        }
    }

    private func rowView(
        _ row: MoonPayPaymentMethodViewState.Row,
        showsDivider: Bool
    ) -> some View {
        Cell(
            config: .init(
                style: .init(dividerLeadingInset: Layout.dividerInset, backgroundColor: .clear),
                showsDivider: showsDivider,
                // A row that cannot be picked has no action, so it neither animates nor reads as a button.
                action: row.isEnabled ? { onSelect(row.id) } : nil
            ),
            leading: {
                CellAssetLeading {
                    if let savedCard = row.savedCard {
                        MoonPaySavedCardIconView(icon: savedCard, size: Layout.iconSize)
                    } else {
                        AssetAvatarView(
                            imageSource: .url(row.iconURL),
                            configuration: AssetAvatarView.Configuration(
                                imageSize: Layout.iconSize,
                                chainIconSize: 0,
                                chainIconPadding: 0,
                                chainIconOffsetX: 0,
                                chainIconOffsetY: 0
                            ),
                            shape: .circle,
                            imageBackgroundColor: .clear
                        )
                    }
                }
                .opacity(contentOpacity(row))
            },
            center: {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(
                            config: .content(
                                .init(
                                    title: row.title,
                                    tags: row.badge.map { [.tag(text: $0)] } ?? []
                                )
                            )
                        )
                    },
                    secondaryRow: {
                        subtitleView(row)
                    }
                )
                .opacity(contentOpacity(row))
            },
            trailing: {
                HStack(spacing: 0) {
                    trailingView(row.trailing)
                        .opacity(contentOpacity(row))
                    if !row.menu.isEmpty {
                        Color.clear
                            .frame(width: Layout.menuButtonSize + Layout.menuButtonTrailing)
                    }
                }
            }
        )
        // Over the cell rather than inside it: a button nested in the cell's own button would let
        // a tap on ⋯ press the row too.
        .overlay(alignment: .trailing) {
            if !row.menu.isEmpty {
                MoonPayRowMenuButton(items: row.menu) { onMenuAction(row.id, $0) }
            }
        }
        // A row that cannot be picked keeps its menu: an expired card can still be removed.
        .opacity(row.isEnabled || !row.menu.isEmpty ? 1 : Layout.disabledOpacity)
    }

    private func contentOpacity(_ row: MoonPayPaymentMethodViewState.Row) -> Double {
        row.isEnabled || row.menu.isEmpty ? 1 : Layout.disabledOpacity
    }

    private func subtitleView(_ row: MoonPayPaymentMethodViewState.Row) -> some View {
        HStack(spacing: 0) {
            if !row.subtitle.isEmpty {
                Text(row.subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            if let suffix = row.subtitleSuffix {
                if !row.subtitle.isEmpty {
                    Text(" · ")
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
                Text(suffix.text)
                    .textStyle(.body2)
                    .foregroundStyle(suffix.color)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func trailingView(_ trailing: MoonPayPaymentMethodViewState.Trailing) -> some View {
        switch trailing {
        case .checkmark:
            CellTrailingAccessory(
                config: .init(
                    color: .accentBlue,
                    icon: SwiftUI.Image.TKUIKit.Icons.Size28.donemarkOutline
                )
            )
        case .none:
            EmptyView()
        }
    }
}

private enum Layout {
    static let providerIconSize: CGFloat = 12
    /// Centres the 12 pt icon on the subtitle's 20 pt line, as the design's 4 pt inset does.
    static let providerIconTop: CGFloat = 4
    static let disabledOpacity: Double = 0.5
    static let sectionTitleInset: CGFloat = 16
    static let dividerInset: CGFloat = 76
    static let sectionSpacing: CGFloat = 16
    static let bottomPadding: CGFloat = 24
    static let iconSize: CGFloat = 44
    static let skeletonRowCount = 4
    static let skeletonSpacing: CGFloat = 16
    static let skeletonPadding: CGFloat = 16
    static let skeletonLineHeight: CGFloat = 16
    static let skeletonTitleWidth: CGFloat = 120
    static let skeletonSubtitleWidth: CGFloat = 80
    static let dividerHeight: CGFloat = 0.5
    static let menuButtonSize: CGFloat = 32
    /// The dots end 16 pt from the cell's edge, as a trailing accessory does.
    static let menuButtonTrailing: CGFloat = 8
    static let menuWidth: CGFloat = 180
    static let menuInset: CGFloat = 8
}

/// The row's "⋯" button; it opens the popup menu anchored to itself.
private struct MoonPayRowMenuButton: View {
    let items: [MoonPayPaymentMethodViewState.MenuItem]
    let onSelect: (String) -> Void

    @State private var anchorView: UIView?
    /// A lone tappable cell pads itself outside its background; the button sits inside that padding.
    @Environment(\.cellsGroupSingleCellConfig) private var singleCellConfig

    var body: some View {
        Button(action: showMenu) {
            SwiftUI.Image.TKUIKit.Icons.Size16.ellipses
                .renderingMode(.template)
                .foregroundStyle(.iconTertiary)
                .frame(width: Layout.menuButtonSize, height: Layout.menuButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, Layout.menuButtonTrailing + (singleCellConfig?.horizontalPadding ?? 0))
        .background(AnchorViewResolver { anchorView = $0 })
    }

    private func showMenu() {
        guard let anchorView else { return }
        TKPopupMenuController.show(
            sourceView: anchorView,
            position: .bottomRight(inset: Layout.menuInset),
            minimumWidth: Layout.menuWidth,
            items: items.enumerated().map { index, item in
                TKPopupMenuItem(
                    title: item.title,
                    icon: item.icon,
                    hasSeparator: index + 1 < items.count,
                    selectionHandler: { onSelect(item.id) }
                )
            },
            isSelectable: false,
            selectedIndex: nil
        )
    }
}
