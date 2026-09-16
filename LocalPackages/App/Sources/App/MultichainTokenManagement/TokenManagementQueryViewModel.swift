import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

@MainActor
final class TokenManagementQueryViewModel: ObservableObject {
    private enum Constants {
        static let pageSize = 30
        static let loadMoreThreshold = 5
    }

    struct RowData {
        var items: [TokenManagementItem]
        var nextCursor: String?
        var hasNextPage: Bool

        static var initial: RowData {
            RowData(items: [], nextCursor: nil, hasNextPage: false)
        }

        var isEmpty: Bool {
            items.isEmpty
        }

        var isInitial: Bool {
            items.isEmpty && nextCursor == nil && !hasNextPage
        }
    }

    enum State {
        case idle
        case refreshing(
            rowData: RowData,
            task: Task<Void, Never>
        )
        case loaded(
            rowData: RowData
        )
        case loadingMore(
            rowData: RowData,
            task: Task<Void, Never>
        )
        case failed(
            rowData: RowData,
            errorMessage: String?
        )
    }

    enum Placeholder: Equatable {
        case empty
        case error(String?)
    }

    struct Presentation {
        let items: [TokenManagementItem]
        let isLoadingMore: Bool
        let showsSkeleton: Bool
        let placeholder: Placeholder?
    }

    @Published private(set) var state: State = .idle

    private let query: String?
    private let categoryID: String
    private let allCategoryID: String
    private let service: TokenManagementService
    private let hidesDustBalances: Bool

    init(
        query: String?,
        categoryID: String,
        allCategoryID: String,
        hidesDustBalances: Bool,
        service: TokenManagementService
    ) {
        self.query = query
        self.categoryID = categoryID
        self.allCategoryID = allCategoryID
        self.hidesDustBalances = hidesDustBalances
        self.service = service
    }

    var presentation: Presentation {
        Self.presentation(for: state)
    }

    static func presentation(for state: State) -> Presentation {
        switch state {
        case .idle:
            return Presentation(
                items: [],
                isLoadingMore: false,
                showsSkeleton: true,
                placeholder: nil
            )
        case let .refreshing(rowData, _):
            if rowData.isInitial {
                return Presentation(
                    items: [],
                    isLoadingMore: false,
                    showsSkeleton: true,
                    placeholder: nil
                )
            }
            return Presentation(
                items: rowData.items,
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.isEmpty ? .empty : nil
            )
        case let .loaded(rowData):
            return Presentation(
                items: rowData.items,
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.isEmpty ? .empty : nil
            )
        case let .loadingMore(rowData, _):
            return Presentation(
                items: rowData.items,
                isLoadingMore: !rowData.isEmpty,
                showsSkeleton: rowData.isEmpty,
                placeholder: nil
            )
        case let .failed(rowData, errorMessage):
            return Presentation(
                items: rowData.items,
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.isEmpty ? .error(errorMessage) : nil
            )
        }
    }

    func appeared() {
        switch state {
        case .idle:
            let task = Task {
                await loadFirstPage(fallbackData: .initial)
            }
            state = .refreshing(rowData: .initial, task: task)
        case let .loaded(rowData) where rowData.isEmpty && rowData.hasNextPage:
            state = .loadingMore(
                rowData: rowData,
                task: Task {
                    await loadNextPage(fallbackData: rowData)
                }
            )
        default:
            break
        }
    }

    func disappeared() {
        let fallbackData: RowData
        switch state {
        case .idle:
            return
        case let .loaded(rowData), let .failed(rowData, _):
            fallbackData = rowData
        case let .refreshing(rowData, task), let .loadingMore(rowData, task):
            task.cancel()
            fallbackData = rowData
        }

        if fallbackData.isInitial {
            state = .idle
        } else {
            state = .loaded(rowData: fallbackData)
        }
    }

    func refresh() async {
        let rowData: RowData
        switch state {
        case .idle:
            rowData = .initial
        case let .loaded(data), let .failed(data, _):
            rowData = data
        case let .refreshing(data, task), let .loadingMore(data, task):
            task.cancel()
            rowData = data
        }

        let task = Task {
            await loadFirstPage(fallbackData: rowData)
        }
        state = .refreshing(rowData: rowData, task: task)
        await task.value
    }

    func loadNextPageIfNeeded(currentItem: TokenManagementItem) {
        let rowData: RowData
        switch state {
        case let .loaded(data):
            rowData = data
        case let .failed(data, _) where !data.items.isEmpty:
            rowData = data
        default:
            return
        }
        guard rowData.hasNextPage else {
            return
        }
        guard let currentIndex = rowData.items.firstIndex(where: { $0.id == currentItem.id }) else {
            return
        }

        let thresholdIndex = max(rowData.items.count - Constants.loadMoreThreshold, 0)
        guard currentIndex >= thresholdIndex else {
            return
        }

        state = .loadingMore(
            rowData: rowData,
            task: Task {
                await loadNextPage(fallbackData: rowData)
            }
        )
    }
}

private extension TokenManagementQueryViewModel {
    var chainID: String? {
        categoryID == allCategoryID ? nil : categoryID
    }

    var normalizedQuery: String? {
        guard let query else {
            return nil
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    func loadFirstPage(fallbackData: RowData) async {
        let page: TokenManagementAssetsPage
        do {
            page = try await service.loadAssets(
                chainID: chainID,
                search: normalizedQuery,
                hidesDustBalances: hidesDustBalances,
                limit: Constants.pageSize,
                cursor: nil
            )
        } catch {
            guard !Task.isCancelled, !isCancelled(error) else {
                return
            }
            state = .failed(
                rowData: fallbackData,
                errorMessage: errorMessage(from: error)
            )
            return
        }

        guard !Task.isCancelled else {
            return
        }

        state = .loaded(
            rowData: RowData(
                items: deduplicated(page.balances.map(makeItem)),
                nextCursor: page.nextCursor,
                hasNextPage: page.nextCursor != nil
            )
        )
        loadNextPageIfStalled(previousItemCount: 0)
    }

    func loadNextPage(fallbackData: RowData) async {
        let page: TokenManagementAssetsPage
        do {
            page = try await service.loadAssets(
                chainID: chainID,
                search: normalizedQuery,
                hidesDustBalances: hidesDustBalances,
                limit: Constants.pageSize,
                cursor: fallbackData.nextCursor
            )
        } catch {
            guard !Task.isCancelled, !isCancelled(error) else {
                return
            }
            state = .failed(
                rowData: fallbackData,
                errorMessage: errorMessage(from: error)
            )
            return
        }

        guard !Task.isCancelled else {
            return
        }

        let previousItemCount = fallbackData.items.count
        let mergedItems = deduplicated(
            merged(
                current: fallbackData.items,
                next: page.balances.map(makeItem)
            )
        )
        state = .loaded(
            rowData: RowData(
                items: mergedItems,
                nextCursor: page.nextCursor,
                hasNextPage: page.nextCursor != nil
            )
        )
        loadNextPageIfStalled(previousItemCount: previousItemCount)
    }

    func loadNextPageIfStalled(previousItemCount: Int) {
        guard case let .loaded(rowData) = state else {
            return
        }
        guard rowData.items.count <= previousItemCount, rowData.hasNextPage else {
            return
        }

        state = .loadingMore(
            rowData: rowData,
            task: Task {
                await loadNextPage(fallbackData: rowData)
            }
        )
    }

    func merged(
        current: [TokenManagementItem],
        next: [TokenManagementItem]
    ) -> [TokenManagementItem] {
        var mergedItems = current
        var indexesByID = Dictionary(
            mergedItems.enumerated()
                .map {
                    ($0.element.id, $0.offset)
                }
        ) { first, _ in
            first
        }

        for item in next {
            if let index = indexesByID[item.id] {
                mergedItems[index] = item
            } else {
                indexesByID[item.id] = mergedItems.count
                mergedItems.append(item)
            }
        }

        return mergedItems
    }

    func deduplicated(_ items: [TokenManagementItem]) -> [TokenManagementItem] {
        var seenIDs = Set<String>()
        var result = [TokenManagementItem]()
        result.reserveCapacity(items.count)
        for item in items {
            guard seenIDs.insert(item.id).inserted else {
                continue
            }
            result.append(item)
        }
        return result
    }

    func makeItem(_ balance: TokenManagementBalanceItem) -> TokenManagementItem {
        TokenManagementItem(
            id: balance.id,
            symbol: balance.symbol,
            title: balance.title,
            chainTag: balance.chainTag,
            avatarImageSource: balance.avatarImageSource,
            subtitle: balance.subtitle,
            subtitleColor: balance.subtitleColor
        )
    }

    func isCancelled(_ error: MultichainServiceError) -> Bool {
        if case .cancelled = error {
            return true
        }
        return false
    }

    func errorMessage(from error: MultichainServiceError) -> String? {
        switch error {
        case .cancelled:
            return nil
        case .connectionError:
            return TKLocales.ConnectionStatus.noInternet
        case let .apiError(message):
            return message
        }
    }
}
