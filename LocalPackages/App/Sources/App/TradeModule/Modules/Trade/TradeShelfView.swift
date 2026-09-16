import SwiftUI
import TKLocalize
import TKUIKit

enum TradeShelfViewContent {
    case skeleton(
        hasHeader: Bool,
        itemsCount: Int
    )
    case content(
        shelf: TradeShelfViewData,
        onOpenSeeAll: (TradeShelfGridViewData) -> Void,
        onOpenAsset: (TradeShelfAssetViewData) -> Void
    )
}

struct TradeShelfView: View {
    let content: TradeShelfViewContent
    let multichainEnabled: Bool
    let selectedGroupID: String?
    let selectedGridID: String?
    let onSelectGroup: (String) -> Void
    let onSelectGrid: (String) -> Void

    init(
        content: TradeShelfViewContent,
        multichainEnabled: Bool = false,
        selectedGroupID: String? = nil,
        selectedGridID: String? = nil,
        onSelectGroup: @escaping (String) -> Void = { _ in },
        onSelectGrid: @escaping (String) -> Void = { _ in }
    ) {
        self.content = content
        self.multichainEnabled = multichainEnabled
        self.selectedGroupID = selectedGroupID
        self.selectedGridID = selectedGridID
        self.onSelectGroup = onSelectGroup
        self.onSelectGrid = onSelectGrid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TradeShelfTitleView(
                content: content,
                multichainEnabled: multichainEnabled,
                onSelectGroup: onSelectGroup,
                selectedGroupForShelf: selectedGroup(for:),
                selectedGridForShelf: selectedGrid(for:)
            )
            TradeShelfContentView(
                content: content,
                onSelectGrid: onSelectGrid,
                selectedGroupForShelf: selectedGroup(for:),
                selectedGridForShelf: selectedGrid(for:)
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeShelfView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
    }

    func selectedGroup(
        for shelf: TradeShelfViewData
    ) -> TradeShelfGroupViewData? {
        guard let selectedGroupID else {
            return shelf.groups.first
        }
        return shelf.groups.first {
            $0.id == selectedGroupID
        } ?? shelf.groups.first
    }

    func selectedGrid(
        for shelf: TradeShelfViewData
    ) -> TradeShelfGridViewData? {
        guard let selectedGroup = selectedGroup(for: shelf) else {
            return nil
        }
        guard let selectedGridID else {
            return selectedGroup.grids.first
        }
        return selectedGroup.grids.first {
            $0.id == selectedGridID
        } ?? selectedGroup.grids.first
    }
}
