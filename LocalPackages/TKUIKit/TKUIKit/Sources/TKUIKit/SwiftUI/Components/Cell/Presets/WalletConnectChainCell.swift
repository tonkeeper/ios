import SwiftUI

public struct WalletConnectChainCellContent {
    public let title: String
    public let address: String
    public let icon: UIImage

    public init(
        title: String,
        address: String,
        icon: UIImage
    ) {
        self.title = title
        self.address = address
        self.icon = icon
    }
}

public struct WalletConnectChainCell: View {
    public let content: WalletConnectChainCellContent
    public let showsDivider: Bool

    public init(
        content: WalletConnectChainCellContent,
        showsDivider: Bool = false
    ) {
        self.content = content
        self.showsDivider = showsDivider
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider
            ),
            leading: {
                Image(uiImage: content.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: Layout.iconSize,
                        height: Layout.iconSize
                    )
                    .clipShape(Circle())
                    .padding(.leading, Layout.leadingPadding)
                    .padding(.vertical, Layout.iconVerticalPadding)
            },
            center: {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(
                            config: .content(
                                CellCenterPrimaryRow.Content(
                                    title: content.title
                                )
                            )
                        )
                    }
                )
            },
            trailing: {
                Text(content.address)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.trailing, Layout.trailingPadding)
                    .padding(.vertical, Layout.trailingVerticalPadding)
            }
        )
    }
}

private extension WalletConnectChainCell {
    enum Layout {
        static let iconSize: CGFloat = 28
        static let leadingPadding: CGFloat = 16
        static let iconVerticalPadding: CGFloat = 14
        static let trailingPadding: CGFloat = 16
        static let trailingVerticalPadding: CGFloat = 16
    }
}
