import SwiftUI
import TKUIKit

public struct MoonPayPaymentMethodViewState {
    public var title: String
    public var sections: [Section]
    public var cryptoSection: CryptoSection?

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

        public init(
            id: String,
            title: String,
            subtitle: String,
            iconURL: URL?,
            savedCard: MoonPaySavedCardIcon? = nil,
            badge: String? = nil,
            subtitleSuffix: SubtitleSuffix? = nil,
            isEnabled: Bool = true,
            trailing: Trailing
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

    public init(title: String, sections: [Section], cryptoSection: CryptoSection? = nil) {
        self.title = title
        self.sections = sections
        self.cryptoSection = cryptoSection
    }
}

public struct MoonPayPaymentMethodView: View {
    private let state: MoonPayPaymentMethodViewState
    private let onSelect: (String) -> Void
    private let onCryptoDeposit: () -> Void
    private let onBack: () -> Void
    private let onClose: () -> Void

    public init(
        state: MoonPayPaymentMethodViewState,
        onSelect: @escaping (String) -> Void,
        onCryptoDeposit: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.onSelect = onSelect
        self.onCryptoDeposit = onCryptoDeposit
        self.onBack = onBack
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    leftIcon: .back(onTap: { _ in onBack() }),
                    title: DefaultModalCardHeader.Title(text: state.title),
                    rightIcon: .close(onTap: { _ in onClose() }),
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.sections) { section in
                        sectionView(section)
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

    private func sectionView(_ section: MoonPayPaymentMethodViewState.Section) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Layout.sectionTitleInset)
                .padding(.top, Layout.sectionTitleTop)
                .padding(.bottom, Layout.sectionTitleBottom)

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, showsDivider: index < section.rows.count - 1)
                }
            }
            .asCellsGroup()
        }
    }

    private func cryptoSectionView(_ section: MoonPayPaymentMethodViewState.CryptoSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Layout.sectionTitleInset)
                .padding(.top, Layout.sectionTitleTop)
                .padding(.bottom, Layout.sectionTitleBottom)

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
                action: { onSelect(row.id) }
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
                            shape: .circle
                        )
                    }
                }
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
            },
            trailing: {
                trailingView(row.trailing)
            }
        )
        .disabled(!row.isEnabled)
        .opacity(row.isEnabled ? 1 : Layout.disabledOpacity)
    }

    private func subtitleView(_ row: MoonPayPaymentMethodViewState.Row) -> some View {
        HStack(spacing: 0) {
            Text(row.subtitle)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
            if let suffix = row.subtitleSuffix {
                Text(" · ")
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
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
    static let disabledOpacity: Double = 0.5
    static let sectionTitleInset: CGFloat = 16
    static let dividerInset: CGFloat = 76
    static let sectionTitleTop: CGFloat = 16
    static let sectionTitleBottom: CGFloat = 8
    static let bottomPadding: CGFloat = 24
    static let iconSize: CGFloat = 44
}
