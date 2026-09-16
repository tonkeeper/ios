import SwiftUI
import TKUIKit

public struct AssetActionButtonsRow: View {
    public struct Item: Identifiable {
        public let id: String
        public let icon: UIImage
        public let title: String
        public let action: () -> Void

        public init(
            id: String,
            icon: UIImage,
            title: String,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.icon = icon
            self.title = title
            self.action = action
        }
    }

    private let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public var body: some View {
        HStack(spacing: Layout.itemSpacing) {
            ForEach(items) { item in
                itemButton(item)
            }
        }
    }

    private func itemButton(_ item: Item) -> some View {
        Button(action: item.action) {
            VStack(spacing: Layout.iconTitleSpacing) {
                SwiftUI.Image(uiImage: item.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                Text(item.title)
                    .textStyle(.label3)
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.titleMinimumScaleFactor)
            }
            .foregroundStyle(.buttonSecondaryForeground)
            .padding(.top, Layout.contentTopPadding)
            .padding(.bottom, Layout.contentBottomPadding)
            .padding(.horizontal, Layout.contentHorizontalPadding)
            .frame(maxWidth: .infinity)
            .background(.buttonSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .accessibilityIdentifier(item.id)
    }
}

private enum Layout {
    static let itemSpacing: CGFloat = 8
    static let iconTitleSpacing: CGFloat = 5
    static let iconSize: CGFloat = 16
    static let contentTopPadding: CGFloat = 12
    static let contentBottomPadding: CGFloat = 10
    static let contentHorizontalPadding: CGFloat = 4
    static let cornerRadius: CGFloat = 16
    static let titleMinimumScaleFactor: CGFloat = 0.7
}
