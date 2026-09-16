import SwiftUI
import TKLocalize
import TKUIKit

struct TradeShelfTitleView: View {
    let content: TradeShelfViewContent
    let multichainEnabled: Bool
    let onSelectGroup: (String) -> Void
    let selectedGroupForShelf: (TradeShelfViewData) -> TradeShelfGroupViewData?
    let selectedGridForShelf: (TradeShelfViewData) -> TradeShelfGridViewData?

    var body: some View {
        ListTitleView(
            config: titleViewConfig
        )
    }
}

extension TradeShelfTitleView {
    private var titleViewConfig: ListTitleView.Config {
        switch content {
        case .skeleton:
            return .shimmer()
        case let .content(shelf, onOpenSeeAll, _):
            let currentSelectedGrid = selectedGridForShelf(shelf)
            return .text(
                shelf.title,
                accessory: titleAccessory(
                    for: shelf,
                    selectedGrid: currentSelectedGrid,
                    onOpenSeeAll: onOpenSeeAll
                ),
                titleAction: titleAction(
                    for: shelf,
                    selectedGrid: currentSelectedGrid,
                    onOpenSeeAll: onOpenSeeAll
                )
            )
        }
    }

    func titleAccessory(
        for shelf: TradeShelfViewData,
        selectedGrid: TradeShelfGridViewData?,
        onOpenSeeAll: @escaping (TradeShelfGridViewData) -> Void
    ) -> ListTitleView.Accessory? {
        if let groupAccessory = groupAccessory(for: shelf) {
            return groupAccessory
        }

        guard let selectedGrid, selectedGrid.seeAllEnabled, !multichainEnabled else {
            return nil
        }

        return ListTitleView.Accessory(
            title: TKLocales.Trade.AssetDetails.Common.seeAll,
            action: {
                onOpenSeeAll(selectedGrid)
            }
        )
    }

    func titleAction(
        for shelf: TradeShelfViewData,
        selectedGrid: TradeShelfGridViewData?,
        onOpenSeeAll: @escaping (TradeShelfGridViewData) -> Void
    ) -> (() -> Void)? {
        guard let selectedGrid, selectedGrid.seeAllEnabled else {
            return nil
        }

        guard hasGroupAccessory(for: shelf) || multichainEnabled else {
            return nil
        }

        return {
            onOpenSeeAll(selectedGrid)
        }
    }

    func hasGroupAccessory(for shelf: TradeShelfViewData) -> Bool {
        shelf.groups.count > 1 && selectedGroupForShelf(shelf) != nil
    }

    func groupAccessory(for shelf: TradeShelfViewData) -> ListTitleView.Accessory? {
        guard hasGroupAccessory(for: shelf), let selectedGroup = selectedGroupForShelf(shelf) else {
            return nil
        }

        return ListTitleView.Accessory(
            menu: ListTitleView.Accessory.Menu(
                title: selectedGroup.title,
                items: shelf.groups.enumerated().map { index, group in
                    TKPopupMenuItem(
                        title: group.title,
                        hasSeparator: index + 1 < shelf.groups.count,
                        selectionHandler: {
                            onSelectGroup(group.id)
                        }
                    )
                },
                selectedIndex: shelf.groups.firstIndex(where: { $0.id == selectedGroup.id })
            )
        )
    }
}
