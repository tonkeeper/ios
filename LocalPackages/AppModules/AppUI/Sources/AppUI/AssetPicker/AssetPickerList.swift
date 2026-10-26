import SwiftUI
import TKUIKit
import UIKit

/// A row of a "pick one" sheet: a payment method, or an asset to pay with.
public struct AssetPickerRowState: Identifiable {
    public enum Icon {
        /// A method logo drawn bare at 28pt.
        case logo(URL?, placeholder: UIImage)
        /// An asset avatar with its network badge.
        case asset(AssetAvatarViewImageSource)
    }

    public enum Accessory {
        case none
        case checkmark
        /// The row opens the picker it belongs to.
        case switchIcon
    }

    public let id: String
    public let icon: Icon
    public let title: String
    public let subtitle: String?
    public let accessory: Accessory

    public init(id: String, icon: Icon, title: String, subtitle: String? = nil, accessory: Accessory = .none) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }
}

public struct AssetPickerList: View {
    private let rows: [AssetPickerRowState]
    private let horizontalPadding: CGFloat
    private let onSelect: (AssetPickerRowState) -> Void

    /// `horizontalPadding` is the group's inset from the container, 0 inside already padded content.
    public init(
        rows: [AssetPickerRowState],
        horizontalPadding: CGFloat = 16,
        onSelect: @escaping (AssetPickerRowState) -> Void
    ) {
        self.rows = rows
        self.horizontalPadding = horizontalPadding
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                AssetPickerRow(row: row, showsDivider: index < rows.count - 1) {
                    onSelect(row)
                }
            }
        }
        .asCellsGroup(config: .init(horizontalPadding: horizontalPadding))
    }
}

struct AssetPickerRow: View {
    @Environment(\.tkPalette) private var palette
    let row: AssetPickerRowState
    let showsDivider: Bool
    let onTap: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(showsDivider: showsDivider, action: onTap),
            leading: {
                icon
                    .padding(.leading, Layout.inset)
            },
            center: {
                CellCenter(
                    primaryRow: {
                        Text(row.title)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                    },
                    secondaryRow: {
                        if let subtitle = row.subtitle {
                            Text(subtitle)
                                .textStyle(.body2)
                                .foregroundStyle(.textSecondary)
                                .lineLimit(1)
                        }
                    },
                    contentInsets: { insets in
                        if row.subtitle == nil {
                            insets.top = Layout.inset
                            insets.bottom = Layout.inset
                        }
                    }
                )
            },
            trailing: {
                switch row.accessory {
                case .none:
                    EmptyView()
                case .checkmark:
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.donemarkOutline)
                        .renderingMode(.template)
                        .foregroundStyle(.accentBlue)
                        .padding(.trailing, Layout.inset)
                case .switchIcon:
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.switch)
                        .renderingMode(.template)
                        .foregroundStyle(.iconTertiary)
                        .padding(.trailing, Layout.inset)
                }
            }
        )
    }

    @ViewBuilder
    private var icon: some View {
        switch row.icon {
        case let .logo(url, placeholder):
            AssetAvatarView(
                imageSource: url.map { .url($0) } ?? .image(placeholder),
                configuration: Layout.logoConfiguration,
                shape: .circle,
                chainIconBackgroundColor: palette.background.content,
                imageBackgroundColor: .clear
            )
            .frame(width: Layout.logoSize, height: Layout.logoSize)
            .padding(.vertical, Layout.logoVerticalPadding)
        case let .asset(source):
            AssetAvatarView(imageSource: source, size: .small)
                .padding(.vertical, Layout.inset)
        }
    }
}

private enum Layout {
    static let inset: CGFloat = 16
    static let logoSize: CGFloat = 28
    static let logoVerticalPadding: CGFloat = 14
    static let logoConfiguration = AssetAvatarView.Configuration(
        imageSize: logoSize,
        chainIconSize: 0,
        chainIconPadding: 0,
        chainIconOffsetX: 0,
        chainIconOffsetY: 0
    )
}
