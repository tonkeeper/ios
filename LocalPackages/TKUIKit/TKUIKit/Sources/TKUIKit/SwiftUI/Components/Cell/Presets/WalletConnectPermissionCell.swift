import SwiftUI

public struct WalletConnectPermissionCellContent {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public struct WalletConnectPermissionCell: View {
    public let content: WalletConnectPermissionCellContent

    public init(
        content: WalletConnectPermissionCellContent
    ) {
        self.content = content
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular
            ),
            leading: {
                SwiftUI.Image.TKUIKit.Icons.Size28.donemarkOutline
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.accentBlue)
                    .frame(
                        width: Layout.iconSize,
                        height: Layout.iconSize
                    )
                    .padding(.leading, Layout.leadingPadding)
                    .padding(.vertical, Layout.iconVerticalPadding)
            },
            center: {
                Text(content.title)
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Layout.titleLeadingPadding)
                    .padding(.trailing, Layout.titleTrailingPadding)
                    .padding(.vertical, Layout.titleVerticalPadding)
            }
        )
    }
}

private extension WalletConnectPermissionCell {
    enum Layout {
        static let iconSize: CGFloat = 28
        static let leadingPadding: CGFloat = 16
        static let iconVerticalPadding: CGFloat = 2
        static let titleLeadingPadding: CGFloat = 12
        static let titleTrailingPadding: CGFloat = 16
        static let titleVerticalPadding: CGFloat = 4
    }
}
