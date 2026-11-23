import SwiftUI
import TKUIKit

public struct MoonPayProviderViewState {
    public var rows: [Row]

    public struct Row: Identifiable {
        public var id: String
        public var title: String
        /// The payment methods the provider takes, such as "Card, Apple Pay".
        public var subtitle: String
        public var image: AssetAvatarViewImageSource
        public var isSelected: Bool

        public init(id: String, title: String, subtitle: String, image: AssetAvatarViewImageSource, isSelected: Bool) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.image = image
            self.isSelected = isSelected
        }
    }

    public init(rows: [Row]) {
        self.rows = rows
    }
}

/// The list of the sheet that picks who the ramp buys through: MoonPay or one of the merchants.
/// The sheet draws the title and the close button.
public struct MoonPayProviderView: View {
    private let state: MoonPayProviderViewState
    private let onSelect: (String) -> Void

    public init(state: MoonPayProviderViewState, onSelect: @escaping (String) -> Void) {
        self.state = state
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row, showsDivider: index < state.rows.count - 1)
            }
        }
        .asCellsGroup()
        .padding(.bottom, Layout.bottomPadding)
        .background(.backgroundPage)
    }

    private func rowView(_ row: MoonPayProviderViewState.Row, showsDivider: Bool) -> some View {
        Cell(
            config: .init(
                style: .init(dividerLeadingInset: Layout.dividerInset, backgroundColor: .clear),
                showsDivider: showsDivider,
                action: { onSelect(row.id) }
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: row.image,
                        configuration: AssetAvatarView.Configuration(
                            imageSize: Layout.iconSize,
                            chainIconSize: 0,
                            chainIconPadding: 0,
                            chainIconOffsetX: 0,
                            chainIconOffsetY: 0
                        ),
                        shape: .rectangle(cornerRadius: Layout.iconCornerRadius)
                    )
                }
            },
            center: {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(config: .content(.init(title: row.title)))
                    },
                    secondaryRow: {
                        Text(row.subtitle)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                )
            },
            trailing: {
                if row.isSelected {
                    CellTrailingAccessory(
                        config: .init(
                            color: .accentBlue,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size28.donemarkOutline
                        )
                    )
                }
            }
        )
        .accessibilityAddTraits(row.isSelected ? .isSelected : [])
    }
}

private enum Layout {
    static let iconSize: CGFloat = 44
    static let iconCornerRadius: CGFloat = 14
    static let dividerInset: CGFloat = 76
    static let bottomPadding: CGFloat = 24
}
