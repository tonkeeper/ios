import Foundation
import KeeperCore

@MainActor
struct MultichainHistoryRowDataReducer {
    typealias RowData = MultichainHistoryQueryViewModel.RowData

    private let itemMapper: MultichainHistoryActivityItemMapper
    private let isSpamCategory: Bool

    init(
        itemMapper: MultichainHistoryActivityItemMapper,
        isSpamCategory: Bool = false
    ) {
        self.itemMapper = itemMapper
        self.isSpamCategory = isSpamCategory
    }

    func mergingFirstPage(
        _ page: MultichainWalletActivitiesPage,
        currentData _: RowData
    ) -> RowData {
        let firstPageItems = deduplicated(items(from: page))
        return RowData(
            items: firstPageItems,
            nextCursor: page.nextCursor,
            hasNextPage: page.nextCursor != nil,
            hasLoadedNextPages: false
        )
    }

    /// `nil` when no item changed, so the caller can skip publishing an identical state.
    func remapping(_ rowData: RowData) -> RowData? {
        var items = rowData.items
        var didChange = false

        for index in items.indices {
            let item = items[index]
            guard itemMapper.nft(for: item.activity) != item.nft else {
                continue
            }
            items[index] = itemMapper.makeItem(activity: item.activity)
            didChange = true
        }

        guard didChange else {
            return nil
        }

        return RowData(
            items: items,
            nextCursor: rowData.nextCursor,
            hasNextPage: rowData.hasNextPage,
            hasLoadedNextPages: rowData.hasLoadedNextPages
        )
    }

    func mergingNextPage(
        _ page: MultichainWalletActivitiesPage,
        currentData: RowData
    ) -> RowData {
        let nextPageItems = items(from: page)
        return RowData(
            items: deduplicated(currentData.items + nextPageItems),
            nextCursor: page.nextCursor,
            hasNextPage: page.nextCursor != nil,
            hasLoadedNextPages: true
        )
    }
}

private extension MultichainHistoryRowDataReducer {
    func items(from page: MultichainWalletActivitiesPage) -> [MultichainHistoryActivityItem] {
        page.activities
            .filter { $0.isSpam == isSpamCategory }
            .map(itemMapper.makeItem)
    }

    func deduplicated(_ items: [MultichainHistoryActivityItem]) -> [MultichainHistoryActivityItem] {
        var indexByIdentity = [MultichainHistoryActivityIdentity: Int]()
        indexByIdentity.reserveCapacity(items.count)

        var result = [MultichainHistoryActivityItem]()
        result.reserveCapacity(items.count)

        for item in items {
            if let index = indexByIdentity[item.id] {
                result[index] = item
            } else {
                indexByIdentity[item.id] = result.count
                result.append(item)
            }
        }
        return result
    }
}
