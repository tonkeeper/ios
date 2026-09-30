import Combine
import Foundation
import KeeperCore
import TKLocalize

@MainActor
final class MultichainHistoryQueryViewModel: ObservableObject {
    private enum Constants {
        static let pageSize = 30
        static let loadMoreThreshold = 5
        /// A page can come back with nothing to show — every activity filtered out as spam or as
        /// the sibling TON account's — and the list then advances on its own. The budget bounds
        /// that chain, so one load cannot walk the whole history; it is refilled by the next load.
        static let maxAutoAdvancedPages = 10
    }

    struct RowData: Equatable {
        let items: [MultichainHistoryActivityItem]
        let nextCursor: String?
        let hasNextPage: Bool
        let hasLoadedNextPages: Bool

        static var initial: RowData {
            RowData(
                items: [],
                nextCursor: nil,
                hasNextPage: false,
                hasLoadedNextPages: false
            )
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
        case filtered
        case error(String?)
    }

    struct Presentation: Equatable {
        let sections: [MultichainHistorySection]
        let isLoadingMore: Bool
        let showsSkeleton: Bool
        let placeholder: Placeholder?
    }

    @Published private(set) var state: State = .idle

    private let multichainState: MultichainWalletState
    private let category: MultichainHistoryCategory
    private let hideDust: Bool?
    private let showsPerps: Bool
    private let multichainService: MultichainService
    private let dateFormatter: DateFormatter
    private let currentDateProvider: () -> Date
    private let onAddFunds: () -> Void
    private let rowDataReducer: MultichainHistoryRowDataReducer
    private let paginationViewModel: MultichainHistoryPaginationViewModel
    private let nftResolver: MultichainActivityNFTResolver

    private var nftResolutionTask: Task<Void, Never>?
    private var nftResolutionObservation: AnyCancellable?
    private var autoAdvancedPages = 0

    init(
        multichainState: MultichainWalletState,
        category: MultichainHistoryCategory,
        hidesDustTransactions: Bool = false,
        showsPerps: Bool = false,
        multichainService: MultichainService,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        nftResolver: MultichainActivityNFTResolver,
        currentDateProvider: @escaping () -> Date = Date.init,
        onAddFunds: @escaping () -> Void = {}
    ) {
        let hideDust = hidesDustTransactions && !category.isSpamCategory ? true : nil
        self.multichainState = multichainState
        self.category = category
        self.hideDust = hideDust
        self.showsPerps = showsPerps
        self.multichainService = multichainService
        self.dateFormatter = dateFormatter
        self.currentDateProvider = currentDateProvider
        self.onAddFunds = onAddFunds
        self.nftResolver = nftResolver

        let itemMapper = MultichainHistoryActivityItemMapper(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            nftProvider: { nftResolver.nft(for: $0) }
        )
        self.rowDataReducer = MultichainHistoryRowDataReducer(
            itemMapper: itemMapper,
            isSpamCategory: category.isSpamCategory
        )
        self.paginationViewModel = MultichainHistoryPaginationViewModel(
            multichainState: multichainState,
            limit: Constants.pageSize,
            category: category,
            hideDust: hideDust,
            showsPerps: showsPerps,
            multichainService: multichainService
        )
        self.nftResolutionObservation = nftResolver.$revision
            .dropFirst()
            .sink { [weak self] _ in
                self?.remapRowData()
            }
    }

    deinit {
        nftResolutionTask?.cancel()
    }

    var presentation: Presentation {
        Self.presentation(
            for: state,
            isDustFiltered: hideDust != nil,
            sectionTitleProvider: sectionTitle(for:),
            currentDate: currentDateProvider(),
            calendar: sectionCalendar
        )
    }

    var hasActivityItems: Bool {
        switch state {
        case .idle:
            return false
        case let .refreshing(rowData, _),
             let .loaded(rowData),
             let .loadingMore(rowData, _),
             let .failed(rowData, _):
            return !rowData.items.isEmpty
        }
    }

    static func presentation(
        for state: State,
        isDustFiltered: Bool,
        sectionTitleProvider: (Date) -> String,
        currentDate: Date,
        calendar: Calendar
    ) -> Presentation {
        let emptyPlaceholder: Placeholder = isDustFiltered ? .filtered : .empty
        switch state {
        case .idle:
            return Presentation(
                sections: [],
                isLoadingMore: false,
                showsSkeleton: true,
                placeholder: nil
            )
        case let .refreshing(rowData, _):
            if rowData == .initial {
                return Presentation(
                    sections: [],
                    isLoadingMore: false,
                    showsSkeleton: true,
                    placeholder: nil
                )
            }
            return Presentation(
                sections: makeSections(
                    items: rowData.items,
                    titleProvider: sectionTitleProvider,
                    currentDate: currentDate,
                    calendar: calendar
                ),
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.items.isEmpty ? emptyPlaceholder : nil
            )
        case let .loaded(rowData):
            return Presentation(
                sections: makeSections(
                    items: rowData.items,
                    titleProvider: sectionTitleProvider,
                    currentDate: currentDate,
                    calendar: calendar
                ),
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.items.isEmpty ? emptyPlaceholder : nil
            )
        case let .loadingMore(rowData, _):
            return Presentation(
                sections: makeSections(
                    items: rowData.items,
                    titleProvider: sectionTitleProvider,
                    currentDate: currentDate,
                    calendar: calendar
                ),
                isLoadingMore: !rowData.items.isEmpty,
                showsSkeleton: rowData.items.isEmpty,
                placeholder: nil
            )
        case let .failed(rowData, errorMessage):
            return Presentation(
                sections: makeSections(
                    items: rowData.items,
                    titleProvider: sectionTitleProvider,
                    currentDate: currentDate,
                    calendar: calendar
                ),
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.items.isEmpty ? .error(errorMessage) : nil
            )
        }
    }

    func appeared() {
        switch state {
        case .idle:
            startFirstPageLoad(fallbackData: .initial)
        case let .loaded(rowData) where rowData.items.isEmpty && rowData.hasNextPage:
            autoAdvancedPages = 0
            state = .loadingMore(
                rowData: rowData,
                task: startLoadingNextPage(fallbackData: rowData)
            )
        case let .loaded(rowData):
            scheduleNFTResolution(for: rowData)
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
        case let .refreshing(rowData, _), let .loadingMore(rowData, _):
            fallbackData = rowData
        }

        cancelActiveFlows()

        if fallbackData == .initial {
            state = .idle
        } else {
            state = .loaded(rowData: fallbackData)
        }
    }

    func addFunds() {
        onAddFunds()
    }

    func refresh() async {
        let rowData: RowData
        switch state {
        case .idle:
            rowData = .initial
        case let .loaded(data), let .failed(data, _):
            rowData = data
        case let .refreshing(data, _), let .loadingMore(data, _):
            rowData = data
        }

        cancelActiveFlows()
        let task = startFirstPageLoad(fallbackData: rowData)
        await task.value
    }

    func loadNextPageIfNeeded(currentItem: MultichainHistoryActivityItem) {
        guard let rowData = paginatableRowData else {
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

        autoAdvancedPages = 0
        state = .loadingMore(
            rowData: rowData,
            task: startLoadingNextPage(fallbackData: rowData)
        )
    }
}

private extension MultichainHistoryQueryViewModel {
    var currentRowData: RowData? {
        switch state {
        case .idle:
            return nil
        case let .refreshing(rowData, _),
             let .loaded(rowData),
             let .loadingMore(rowData, _),
             let .failed(rowData, _):
            return rowData
        }
    }

    var paginatableRowData: RowData? {
        switch state {
        case let .loaded(rowData):
            return rowData
        case .idle, .refreshing, .loadingMore, .failed:
            return nil
        }
    }

    @discardableResult
    func startFirstPageLoad(fallbackData: RowData) -> Task<Void, Never> {
        autoAdvancedPages = 0
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await self.loadFirstPage(fallbackData: fallbackData)
        }
        state = .refreshing(rowData: fallbackData, task: task)
        return task
    }

    func loadFirstPage(fallbackData: RowData) async {
        let page: MultichainWalletActivitiesPage
        do {
            page = try await loadPage(cursor: nil)
        } catch {
            guard !Task.isCancelled, !isCancelled(error) else {
                return
            }
            applyFailure(error, fallbackData: fallbackData)
            return
        }

        guard !Task.isCancelled else {
            return
        }

        applyFirstPage(page, fallbackData: fallbackData)
        finishFirstPageLoad()
        loadNextPageIfStalled(previousItemCount: 0)
    }

    func applyFirstPage(
        _ page: MultichainWalletActivitiesPage,
        fallbackData: RowData
    ) {
        let rowData = rowDataReducer.mergingFirstPage(
            page,
            currentData: currentRowData ?? fallbackData
        )

        switch state {
        case let .refreshing(_, task):
            state = .refreshing(rowData: rowData, task: task)
        case let .loadingMore(_, task):
            state = .loadingMore(rowData: rowData, task: task)
        case .idle, .loaded, .failed:
            state = .loaded(rowData: rowData)
        }

        scheduleNFTResolution(for: rowData)
    }

    func scheduleNFTResolution(for rowData: RowData) {
        let activities = rowData.items.map(\.activity)
        guard !activities.isEmpty else {
            return
        }

        nftResolutionTask?.cancel()
        nftResolutionTask = Task { [nftResolver] in
            await nftResolver.resolve(activities: activities)
        }
    }

    func remapRowData() {
        guard let rowData = currentRowData,
              let remapped = rowDataReducer.remapping(rowData)
        else {
            return
        }

        switch state {
        case .idle:
            break
        case let .refreshing(_, task):
            state = .refreshing(rowData: remapped, task: task)
        case .loaded:
            state = .loaded(rowData: remapped)
        case let .loadingMore(_, task):
            state = .loadingMore(rowData: remapped, task: task)
        case let .failed(_, errorMessage):
            state = .failed(rowData: remapped, errorMessage: errorMessage)
        }
    }

    func finishFirstPageLoad() {
        if case let .refreshing(rowData, _) = state {
            state = .loaded(rowData: rowData)
        }
    }

    func startLoadingNextPage(fallbackData: RowData) -> Task<Void, Never> {
        paginationViewModel.start(
            cursor: fallbackData.nextCursor,
            onSuccess: { [weak self] page in
                self?.applyNextPage(page, fallbackData: fallbackData)
            },
            onFailure: { [weak self] error in
                self?.applyFailure(error, fallbackData: fallbackData)
            }
        )
    }

    func loadPage(cursor: String?) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        try await category.fetchActivities(
            using: multichainService,
            state: multichainState,
            limit: Constants.pageSize,
            cursor: cursor,
            hideDust: hideDust,
            showsPerps: showsPerps
        )
    }

    func applyNextPage(
        _ page: MultichainWalletActivitiesPage,
        fallbackData: RowData
    ) {
        let baseData = currentRowData ?? fallbackData
        let rowData = rowDataReducer.mergingNextPage(page, currentData: baseData)
        state = .loaded(rowData: rowData)
        scheduleNFTResolution(for: rowData)
        loadNextPageIfStalled(previousItemCount: baseData.items.count)
    }

    func loadNextPageIfStalled(previousItemCount: Int) {
        guard case let .loaded(rowData) = state else {
            return
        }
        guard rowData.items.count <= previousItemCount, rowData.hasNextPage else {
            return
        }
        guard autoAdvancedPages < Constants.maxAutoAdvancedPages else {
            return
        }
        autoAdvancedPages += 1
        state = .loadingMore(
            rowData: rowData,
            task: startLoadingNextPage(fallbackData: rowData)
        )
    }

    func applyFailure(
        _ error: MultichainServiceError,
        fallbackData: RowData
    ) {
        state = .failed(
            rowData: currentRowData ?? fallbackData,
            errorMessage: errorMessage(from: error)
        )
    }

    func cancelActiveFlows() {
        switch state {
        case let .refreshing(_, task), let .loadingMore(_, task):
            task.cancel()
        case .idle, .loaded, .failed:
            break
        }
        paginationViewModel.cancel()
        nftResolutionTask?.cancel()
        nftResolutionTask = nil
    }

    func sectionTitle(for date: Date) -> String {
        let calendar = sectionCalendar
        let currentDate = currentDateProvider()
        if calendar.isDate(date, inSameDayAs: currentDate) {
            return TKLocales.Dates.today
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate),
           calendar.isDate(date, inSameDayAs: yesterday)
        {
            return TKLocales.Dates.yesterday
        }

        if calendar.isDate(date, equalTo: currentDate, toGranularity: .month) {
            dateFormatter.dateFormat = "d MMMM"
        } else if calendar.isDate(date, equalTo: currentDate, toGranularity: .year) {
            dateFormatter.dateFormat = "LLLL"
        } else {
            dateFormatter.dateFormat = "LLLL y"
        }
        return dateFormatter.string(from: date).capitalized
    }

    var sectionCalendar: Calendar {
        var calendar = dateFormatter.calendar ?? Calendar.current
        if let timeZone = dateFormatter.timeZone {
            calendar.timeZone = timeZone
        }
        return calendar
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

    func isCancelled(_ error: MultichainServiceError) -> Bool {
        if case .cancelled = error {
            return true
        }
        return false
    }
}

private extension MultichainHistoryQueryViewModel {
    static func makeSections(
        items: [MultichainHistoryActivityItem],
        titleProvider: (Date) -> String,
        currentDate: Date,
        calendar: Calendar
    ) -> [MultichainHistorySection] {
        var sections = [MultichainHistorySection]()
        var sectionIndexes = [Date: Int]()

        for item in items {
            guard let sectionDate = sectionDate(
                for: item.activity.blockTime,
                currentDate: currentDate,
                calendar: calendar
            ) else {
                continue
            }

            if let sectionIndex = sectionIndexes[sectionDate] {
                let section = sections[sectionIndex]
                sections[sectionIndex] = MultichainHistorySection(
                    id: section.id,
                    title: section.title,
                    groups: appending(item: item, to: section.groups)
                )
            } else {
                guard let group = MultichainHistoryActivityGroup(items: [item]) else {
                    continue
                }
                let section = MultichainHistorySection(
                    id: sectionDate,
                    title: titleProvider(sectionDate),
                    groups: [group]
                )
                sectionIndexes[sectionDate] = sections.count
                sections.append(section)
            }
        }

        return sections
    }

    static func appending(
        item: MultichainHistoryActivityItem,
        to groups: [MultichainHistoryActivityGroup]
    ) -> [MultichainHistoryActivityGroup] {
        var groups = groups

        if let lastGroup = groups.last,
           let lastItem = lastGroup.items.last,
           let lastKey = MultichainHistoryEventKey(activity: lastItem.activity),
           let key = MultichainHistoryEventKey(activity: item.activity),
           lastKey == key,
           let mergedGroup = MultichainHistoryActivityGroup(items: lastGroup.items + [item])
        {
            groups[groups.count - 1] = mergedGroup
            return groups
        }

        if let group = MultichainHistoryActivityGroup(items: [item]) {
            groups.append(group)
        }
        return groups
    }

    static func sectionDate(
        for date: Date,
        currentDate: Date,
        calendar: Calendar
    ) -> Date? {
        let components: Set<Calendar.Component> = if calendar.isDate(date, equalTo: currentDate, toGranularity: .month) {
            [.year, .month, .day]
        } else {
            [.year, .month]
        }

        return calendar.date(
            from: calendar.dateComponents(
                components,
                from: date
            )
        )
    }
}
