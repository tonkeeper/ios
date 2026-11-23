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
        RowData(
            items: items(from: page),
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
            let remapped = itemMapper.makeItem(
                activity: items[index].activity,
                occurrence: items[index].id.occurrence
            )
            guard remapped != items[index] else {
                continue
            }
            items[index] = remapped
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
        let activities = page.activities.filter { $0.isSpam == isSpamCategory }
        var transactionStatuses = [MultichainHistoryActivityIdentity: MultichainActivityStatus]()
        for activity in activities {
            let identity = MultichainHistoryActivityIdentity(activity: activity)
            if !identity.txIds.isEmpty {
                transactionStatuses[identity] = activity.status
            }
        }
        let items = currentData.items.filter { item in
            transactionStatuses[item.id.activity].map { $0 == item.activity.status } ?? true
        }
        return RowData(
            items: items + itemMapper.makeItems(activities, after: items),
            nextCursor: page.nextCursor,
            hasNextPage: page.nextCursor != nil,
            hasLoadedNextPages: true
        )
    }
}

private extension MultichainHistoryRowDataReducer {
    func items(from page: MultichainWalletActivitiesPage) -> [MultichainHistoryActivityItem] {
        itemMapper.makeItems(page.activities.filter { $0.isSpam == isSpamCategory })
    }
}
