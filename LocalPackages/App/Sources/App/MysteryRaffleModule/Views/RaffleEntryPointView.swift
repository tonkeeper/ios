import SwiftUI
import TKUIKit
import UIKit

struct RaffleEntryPointView<Icon: View>: View {
    let title: String
    var titleTag: TKTagSwiftUIViewConfig?
    var badgeText: String?
    var badgeColor: TKColor?
    var action: () -> Void = {}
    @ViewBuilder let icon: Icon

    var body: some View {
        Cell(
            config: Cell.Config(action: action),
            leading: {
                icon
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .padding(.leading, Layout.horizontalPadding)
                    .padding(.vertical, Layout.iconVerticalPadding)
            },
            center: {
                CellCenter {
                    HStack(spacing: 0) {
                        Text(title)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                        if let titleTag {
                            TKTagSwiftUIView(config: titleTag)
                        }
                    }
                } contentInsets: { insets in
                    insets.leading = Layout.iconTitleSpacing
                    insets.top = Layout.titleVerticalPadding
                    insets.bottom = Layout.titleVerticalPadding
                }
            },
            trailing: {
                HStack(spacing: 0) {
                    if let badgeText {
                        badgePill(badgeText)
                    }

                    CellTrailingAccessory(
                        config: CellTrailingAccessory.Config(
                            color: .iconTertiary,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                            iconSize: Layout.chevronSize
                        )
                    )
                }
            }
        )
        .asCellsGroup(config: .init(horizontalPadding: 0))
    }

    private func badgePill(_ text: String) -> some View {
        Text(text)
            .textStyle(.label2)
            .foregroundStyle(badgeColor ?? .textAccent)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Layout.pillHorizontalPadding)
            .padding(.vertical, Layout.pillVerticalPadding)
            .background((badgeColor ?? .accentBlue).opacity(0.12))
            .clipShape(Capsule())
            .padding(.trailing, Layout.pillTrailingSpacing)
    }
}

struct RaffleEntryPointsView: View {
    let entries: [MysteryRafflePresentation]
    let onOpen: (String) -> Void
    var onAppear: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(entries, id: \.raffle.id) { entry in
                RaffleEntryPointView(
                    title: entry.compactTitle,
                    badgeText: entry.badgeText,
                    action: { onOpen(entry.raffle.id) }
                ) {
                    TemplateIcon(image: entry.compactSymbol.image, tint: .accentBlue, size: Layout.iconSize)
                }
                .onAppear { onAppear(entry.raffle.id) }
            }
        }
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let iconSize: CGFloat = 28
    static let iconVerticalPadding: CGFloat = 14
    static let iconTitleSpacing: CGFloat = 12
    static let titleVerticalPadding: CGFloat = 16
    static let chevronSize: CGFloat = 16
    static let pillHorizontalPadding: CGFloat = 12
    static let pillVerticalPadding: CGFloat = 3
    static let pillTrailingSpacing: CGFloat = 8
}
