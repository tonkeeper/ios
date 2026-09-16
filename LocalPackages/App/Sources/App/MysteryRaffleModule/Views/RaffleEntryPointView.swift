import SwiftUI
import TKUIKit
import UIKit

struct RaffleEntryPointView: View {
    let title: String
    var ticketsText: String?
    var action: () -> Void = {}

    var body: some View {
        Cell(
            config: Cell.Config(action: action),
            leading: {
                TemplateIcon(image: .TKUIKit.Icons.Size28.ticket, tint: .accentBlue, size: Layout.iconSize)
                    .padding(.leading, Layout.horizontalPadding)
                    .padding(.vertical, Layout.iconVerticalPadding)
            },
            center: {
                CellCenter {
                    Text(title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                } contentInsets: { insets in
                    insets.leading = Layout.iconTitleSpacing
                    insets.top = Layout.titleVerticalPadding
                    insets.bottom = Layout.titleVerticalPadding
                }
            },
            trailing: {
                HStack(spacing: 0) {
                    if let ticketsText {
                        ticketsPill(ticketsText)
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

    private func ticketsPill(_ text: String) -> some View {
        Text(text)
            .textStyle(.label2)
            .foregroundStyle(.textAccent)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Layout.pillHorizontalPadding)
            .padding(.vertical, Layout.pillVerticalPadding)
            .background(.accentBlue.opacity(0.12))
            .clipShape(Capsule())
            .padding(.trailing, Layout.pillTrailingSpacing)
    }
}

private extension RaffleEntryPointView {
    enum Layout {
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
}
