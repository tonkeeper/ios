import SwiftUI
import UIKit

public struct ListTitleView: View {
    public var config: Config
    @State private var accessoryAnchorView: UIView?

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        content
            .frame(height: Layout.height)
    }

    @ViewBuilder
    private var content: some View {
        switch config {
        case let .text(title, accessory, titleAction):
            HStack(alignment: .center, spacing: 0) {
                titleView(
                    title,
                    action: titleAction
                )

                Spacer(minLength: 0)

                if let accessory {
                    accessoryView(accessory)
                }
            }
        case let .shimmer(hasAccessory):
            HStack(alignment: .center, spacing: 0) {
                ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .value(12)))
                    .frame(width: 107, height: 24)
                Spacer(minLength: 0)
                if hasAccessory {
                    ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .value(12)))
                        .frame(width: 55, height: 24)
                }
            }
        }
    }

    @ViewBuilder
    private func titleView(
        _ title: String,
        action: (() -> Void)?
    ) -> some View {
        if let action {
            Button(action: action) {
                HStack(spacing: Layout.titleActionSpacing) {
                    titleText(title)

                    Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.iconSecondary)
                        .frame(
                            width: Layout.titleActionIconSize,
                            height: Layout.titleActionIconSize
                        )
                        .offset(y: 1)
                }
            }
            .buttonStyle(TKTapAnimationButtonStyle())
        } else {
            titleText(title)
        }
    }

    private func titleText(_ title: String) -> some View {
        Text(title)
            .textStyle(.label1)
            .foregroundStyle(.textPrimary)
    }

    @ViewBuilder
    private func accessoryView(_ accessory: Accessory) -> some View {
        switch accessory.kind {
        case let .button(button):
            Button {
                button.action()
            } label: {
                HStack(spacing: button.icon == nil ? 0 : Layout.accessoryIconSpacing) {
                    Text(button.title)
                        .textStyle(button.textStyle)

                    if let icon = button.icon {
                        Image(uiImage: icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: Layout.accessoryIconSize,
                                height: Layout.accessoryIconSize
                            )
                            .offset(y: button.iconVerticalOffset)
                    }
                }
                .foregroundStyle(button.foregroundColor)
            }
            .buttonStyle(TKTapAnimationButtonStyle())
            .padding(.top, Layout.accessoryBelowCentreNudge)
        case let .menu(menu):
            Button {
                showMenu(menu)
            } label: {
                menuAccessoryLabel(title: menu.title)
            }
            .buttonStyle(TKTapAnimationButtonStyle())
            .background(
                AnchorViewResolver { view in
                    accessoryAnchorView = view
                }
            )
        }
    }

    private func menuAccessoryLabel(title: String) -> some View {
        HStack(spacing: Layout.menuAccessoryContentSpacing) {
            Image(uiImage: .TKUIKit.Icons.Size16.globe)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.menuAccessoryIconSize, height: Layout.menuAccessoryIconSize)

            Text(title)
                .textStyle(.label2)
                .lineLimit(1)

            Image(uiImage: .TKUIKit.Icons.Size16.switch)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.iconSecondary)
                .frame(width: Layout.menuAccessoryIconSize, height: Layout.menuAccessoryIconSize)
        }
        .foregroundStyle(.buttonSecondaryForeground)
        .padding(.horizontal, Layout.menuAccessoryHorizontalPadding)
        .frame(height: Layout.menuAccessoryHeight)
        .background(
            Capsule(style: .continuous)
                .fill(.buttonSecondaryBackground)
        )
    }

    private func showMenu(_ menu: Accessory.Menu) {
        guard let accessoryAnchorView else {
            return
        }

        TKPopupMenuController.show(
            sourceView: accessoryAnchorView,
            position: .bottomRight(inset: Layout.menuAccessoryPopupInset),
            minimumWidth: menu.minimumWidth,
            items: menu.items,
            selectedIndex: menu.selectedIndex
        )
    }
}

public extension ListTitleView {
    struct Accessory {
        struct Button {
            var title: String
            var icon: UIImage?
            var iconVerticalOffset: CGFloat
            var foregroundColor: TKColor
            var textStyle: TKTextStyle
            var action: () -> Void
        }

        public struct Menu {
            var title: String
            var minimumWidth: CGFloat
            var items: [TKPopupMenuItem]
            var selectedIndex: Int?

            public init(
                title: String,
                minimumWidth: CGFloat = 160,
                items: [TKPopupMenuItem],
                selectedIndex: Int?
            ) {
                self.title = title
                self.minimumWidth = minimumWidth
                self.items = items
                self.selectedIndex = selectedIndex
            }
        }

        enum Kind {
            case button(Button)
            case menu(Menu)
        }

        var kind: Kind

        public init(
            title: String,
            icon: UIImage? = nil,
            iconVerticalOffset: CGFloat = 0,
            foregroundColor: TKColor = .accentBlue,
            textStyle: TKTextStyle = .body2,
            action: @escaping () -> Void
        ) {
            self.kind = .button(
                Button(
                    title: title,
                    icon: icon,
                    iconVerticalOffset: iconVerticalOffset,
                    foregroundColor: foregroundColor,
                    textStyle: textStyle,
                    action: action
                )
            )
        }

        public init(menu: Menu) {
            self.kind = .menu(menu)
        }
    }

    enum Config {
        case text(String, accessory: Accessory? = nil, titleAction: (() -> Void)? = nil)
        case shimmer(hasAccessory: Bool = true)
    }

    enum Layout {
        static let height: CGFloat = 48
        static let accessoryBelowCentreNudge: CGFloat = 2
        static let accessoryIconSpacing: CGFloat = 6
        static let accessoryIconSize: CGFloat = 16
        static let titleActionSpacing: CGFloat = 2
        static let titleActionIconSize: CGFloat = 16
        static let menuAccessoryHeight: CGFloat = 32
        static let menuAccessoryIconSize: CGFloat = 16
        static let menuAccessoryContentSpacing: CGFloat = 6
        static let menuAccessoryHorizontalPadding: CGFloat = 12
        static let menuAccessoryPopupInset: CGFloat = 8
    }
}
