import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct PerpsSortMenuButton: View {
    let sort: PerpsMarketsSort
    let menuPosition: TKPopupMenuPosition
    let onSelect: (PerpsMarketsSort) -> Void

    @State private var anchorView: UIView?

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: Layout.spacing) {
                Text(sort.title)
                    .textStyle(.label2)
                    .foregroundStyle(.buttonSecondaryForeground)
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.switch)
                    .renderingMode(.template)
                    .foregroundStyle(.iconSecondary)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(
                Capsule().fill(.buttonSecondaryBackground)
            )
        }
        .buttonStyle(.plain)
        .background(
            AnchorViewResolver { anchorView = $0 }
        )
    }

    func showMenu() {
        guard let sourceView = anchorView else { return }
        let options = PerpsMarketsSort.allCases
        TKPopupMenuController.show(
            sourceView: sourceView,
            position: menuPosition,
            minimumWidth: Layout.menuWidth,
            items: options.enumerated().map { index, option in
                TKPopupMenuItem(
                    title: option.title,
                    hasSeparator: index + 1 < options.count,
                    selectionHandler: { onSelect(option) }
                )
            },
            selectedIndex: options.firstIndex(of: sort)
        )
    }
}

extension PerpsMarketsSort {
    var title: String {
        switch self {
        case .volume:
            TKLocales.Perps.volume
        case .priceChange:
            TKLocales.Perps.priceChange
        case .openInterest:
            TKLocales.Perps.openInterest
        }
    }
}

private enum Layout {
    static let spacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    static let menuWidth: CGFloat = 220
}
