import SwiftUI
import UIKit

public struct TabCategoryView: View {
    public enum Style: Hashable {
        case primary
        case secondary
        case custom(Colors)
    }

    public struct Colors: Hashable {
        let selectedForegroundColor: TKColor
        let unselectedForegroundColor: TKColor
        let selectedBackgroundColor: TKColor
        let unselectedBackgroundColor: TKColor

        public init(
            selectedForegroundColor: TKColor,
            unselectedForegroundColor: TKColor,
            selectedBackgroundColor: TKColor,
            unselectedBackgroundColor: TKColor
        ) {
            self.selectedForegroundColor = selectedForegroundColor
            self.unselectedForegroundColor = unselectedForegroundColor
            self.selectedBackgroundColor = selectedBackgroundColor
            self.unselectedBackgroundColor = unselectedBackgroundColor
        }

        func foregroundColor(isSelected: Bool) -> TKColor {
            isSelected ? selectedForegroundColor : unselectedForegroundColor
        }

        func backgroundColor(isSelected: Bool) -> TKColor {
            isSelected ? selectedBackgroundColor : unselectedBackgroundColor
        }
    }

    let title: String
    let image: UIImage?
    let isSelected: Bool
    let style: Style
    let accessibilityIdentifier: String?
    let action: () -> Void

    public init(
        title: String,
        image: UIImage? = nil,
        isSelected: Bool,
        style: Style = .primary,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.image = image
        self.isSelected = isSelected
        self.style = style
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    if let image {
                        Image(uiImage: image)
                            .padding(.trailing, 1)
                    }
                    Text(title)
                        .textStyle(.label2)
                        .padding(.horizontal, Layout.labelPadding)
                }
                .foregroundStyle(colors.foregroundColor(isSelected: isSelected))
                Spacer()
            }
            .padding(.horizontal, Layout.contentPadding)
            .frame(height: Layout.height)
            .background(
                Capsule(style: .continuous)
                    .fill(colors.backgroundColor(isSelected: isSelected))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var colors: Colors {
        switch style {
        case .primary:
            Colors(
                selectedForegroundColor: .buttonPrimaryForeground,
                unselectedForegroundColor: .buttonSecondaryForeground,
                selectedBackgroundColor: .accentBlue,
                unselectedBackgroundColor: .buttonSecondaryBackground
            )
        case .secondary:
            Colors(
                selectedForegroundColor: .buttonSecondaryForeground,
                unselectedForegroundColor: .buttonSecondaryForeground,
                selectedBackgroundColor: .backgroundContentAttention,
                unselectedBackgroundColor: .buttonSecondaryBackground
            )
        case let .custom(colors):
            colors
        }
    }
}

private extension TabCategoryView {
    enum Layout {
        static let height: CGFloat = 32
        static let labelPadding: CGFloat = 6
        static let contentPadding: CGFloat = 6
    }
}

#Preview {
    HStack(spacing: 12) {
        TabCategoryView(
            title: "All",
            isSelected: true,
            action: {}
        )
        TabCategoryView(
            title: "Bitcoin",
            image: .TKUIKit.Icons.Size20.btcChain,
            isSelected: false,
            action: {}
        )
        TabCategoryView(
            title: "Stocks",
            isSelected: false,
            action: {}
        )
        TabCategoryView(
            title: "ETFs",
            isSelected: false,
            action: {}
        )
        Spacer()
    }
    .padding(.horizontal, 12)
    .debugPreview(background: .page)
}
