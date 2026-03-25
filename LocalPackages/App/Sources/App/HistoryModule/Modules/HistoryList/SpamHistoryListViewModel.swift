import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

final class SpamHistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput, HistoryListModuleInput {
    private enum State {
        enum Pagination {
            case none
            case loading
            case error
            case spamFooter(date: String)
        }

        struct Content {
            var isEmpty: Bool {
                sections.isEmpty
            }

            let sections: [HistoryList.Section]
        }

        case loading
        case content(Content, pagination: Pagination)

        var sections: [HistoryList.Section] {
            switch self {
            case .loading:
                return []
            case let .content(content, _):
                return content.sections
            }
        }
    }

    // MARK: - State

    private var listState: State = .loading {
        didSet { didUpdateListState() }
    }

    var filter: HistoryList.Filter {
        get { queue.sync { _filter } }
        set { queue.async { [weak self] in self?._filter = newValue } }
    }

    private var _filter: HistoryList.Filter = .spam

    private var relativeDate = Date()
    private var events = [HistoryEvent]() {
        didSet {
            try? cacheProvider.setCache(events: events, wallet: wallet)
        }
    }

    private var firstReload = true
    private var spamPaginationStopped = false
    private var hasTriedOneExtraLoad = false
    private let queue = DispatchQueue(label: "SpamHistoryListViewModelImplementationQueue")

    private var eventCellConfigurations = [AccountEvent.EventID: HistoryCell.Model]()
    private var paginationCellConfiguration = HistoryListPaginationCell.Model(state: .none)

    // MARK: - Dependencies

    private let wallet: Wallet
    private let historyLoader: HistoryPaginationLoader
    private let dateFormatter: DateFormatter
    private let backgroundUpdate: BackgroundUpdate
    private let decryptedCommentStore: DecryptedCommentStore
    private let nftManagmentStore: WalletNFTsManagementStore
    private let appSettingsStore: AppSettingsStore
    private let transactionsManagementStore: TransactionsManagement.Store
    private let accountEventMapper: AccountEventMapper
    private let historyEventMapper: HistoryEventMapper
    private let tronEventMapper: TronEventMapper
    private let nftService: NFTService
    private let cacheProvider: HistoryListCacheProvider

    // MARK: - Init

    init(
        wallet: Wallet,
        historyLoader: HistoryPaginationLoader,
        dateFormatter: DateFormatter,
        backgroundUpdate: BackgroundUpdate,
        decryptedCommentStore: DecryptedCommentStore,
        nftManagmentStore: WalletNFTsManagementStore,
        appSettingsStore: AppSettingsStore,
        transactionsManagementStore: TransactionsManagement.Store,
        accountEventMapper: AccountEventMapper,
        historyEventMapper: HistoryEventMapper,
        tronEventMapper: TronEventMapper,
        nftService: NFTService,
        cacheProvider: HistoryListCacheProvider
    ) {
        self.wallet = wallet
        self.historyLoader = historyLoader
        self.dateFormatter = dateFormatter
        self.backgroundUpdate = backgroundUpdate
        self.decryptedCommentStore = decryptedCommentStore
        self.nftManagmentStore = nftManagmentStore
        self.appSettingsStore = appSettingsStore
        self.transactionsManagementStore = transactionsManagementStore
        self.accountEventMapper = accountEventMapper
        self.historyEventMapper = historyEventMapper
        self.tronEventMapper = tronEventMapper
        self.nftService = nftService
        self.cacheProvider = cacheProvider
    }

    // MARK: - HistoryListModuleOutput

    var didSelectEvent: ((HistoryListSelectedEvent) -> Void)?
    var didSelectNFT: ((_ wallet: Wallet, _ address: TonSwift.Address) -> Void)?
    var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload, _ eventId: String) -> Void)?
    var didUpdateState: ((HistoryList.State) -> Void)?

    // MARK: - HistoryListViewModel

    var snapshotUpdate: ((HistoryList.Snapshot) -> Void)?
    var scrollToTop: ((Bool) -> Void)?

    func viewDidLoad() {
        setupObservers()

        // For spam, first check cached events
        if let cachedEvents = try? cacheProvider.getCache(wallet: wallet), !cachedEvents.isEmpty {
            let transactionsManagementState = transactionsManagementStore.state
            let spamEvents = filterSpamEvents(cachedEvents, transactionsManagementState: transactionsManagementState)

            if !spamEvents.isEmpty {
                // Show cached spam events immediately and show footer (don't load more)
                self.events = cachedEvents
                showSpamEvents(spamEvents, transactionsManagementState: transactionsManagementState)
                // Also show footer to indicate spam range
                showSpamFooterWithEvents(transactionsManagementState: transactionsManagementState)
                return
            } else {
                // No spam in cache, make one request to check for newer spam
                self.events = cachedEvents
                // Continue to setup loader for one more try
            }
        }

        // No cache or empty cache, start loading
        historyLoader.eventHandler = { [weak self] event in
            self?.didGetHistoryLoaderEvent(event)
        }
        historyLoader.reload(force: true)
    }

    func reload(force: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            resetSectionsCalculationState()
            historyLoader.reload(force: force)
        }
    }

    func loadNextPage() {
        // Spam pagination is controlled internally
        if !spamPaginationStopped {
            historyLoader.loadNext()
        }
    }

    func getEventCellConfiguration(eventID: HistoryList.EventID) -> HistoryCell.Model? {
        eventCellConfigurations[eventID]
    }

    func getPaginationCellConfiguration() -> HistoryListPaginationCell.Model {
        paginationCellConfiguration
    }

    func getSectionHeaderTitle(sectionID: HistoryList.Section.ID) -> String? {
        formatEventSectionDate(sectionID)
    }

    // MARK: - Private Methods

    private func setupObservers() {
        appSettingsStore.addObserver(self) { observer, event in
            observer.didGetAppSettingsStoreEvent(event)
        }
        decryptedCommentStore.addObserver(self) { observer, event in
            observer.didGetDecryptedCommentStoreEvent(event)
        }
        backgroundUpdate.addEventObserver(self) { observer, wallet, _ in
            guard wallet == observer.wallet else { return }
            observer.queue.async {
                observer.reload(force: true)
            }
        }
        nftManagmentStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateState(wallet):
                guard wallet == observer.wallet else { return }
                observer.didUpdateNFTsState()
            }
        }
        transactionsManagementStore.addObserver(self)
    }

    private func showSpamEvents(_ spamEvents: [HistoryEvent], transactionsManagementState: TransactionsManagement.TransactionsStates) {
        resetSectionsCalculationState()
        let sections = calculateSections(sections: [], events: spamEvents)
        update(withEvents: spamEvents)
        listState = .content(State.Content(sections: sections), pagination: .none)
    }

    private func showSpamFooter(transactionsManagementState: TransactionsManagement.TransactionsStates) {
        spamPaginationStopped = true
        let footerPagination = createSpamFooter(transactionsManagementState: transactionsManagementState)
        listState = .content(State.Content(sections: []), pagination: footerPagination)
    }

    private func showSpamFooterWithEvents(transactionsManagementState: TransactionsManagement.TransactionsStates) {
        spamPaginationStopped = true
        let footerPagination = createSpamFooter(transactionsManagementState: transactionsManagementState)
        // Update current state to add footer while keeping existing sections
        if case let .content(content, _) = listState {
            listState = .content(content, pagination: footerPagination)
        }
    }

    private func filterSpamEvents(_ events: [HistoryEvent], transactionsManagementState: TransactionsManagement.TransactionsStates) -> [HistoryEvent] {
        events.filter { event in
            event.isScam || transactionsManagementState.states[event.eventId] == .spam
        }
    }

    private func createSpamFooter(transactionsManagementState: TransactionsManagement.TransactionsStates) -> State.Pagination {
        let allSpamEvents = filterSpamEvents(self.events, transactionsManagementState: transactionsManagementState)
        if let earliestSpamEvent = allSpamEvents.min(by: { $0.date < $1.date }) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            let spamDateString = dateFormatter.string(from: earliestSpamEvent.date)
            return .spamFooter(date: "Spam after \(spamDateString) is shown")
        } else {
            return .spamFooter(date: "No spam events found")
        }
    }

    private func didGetHistoryLoaderEvent(_ event: HistoryPaginationLoader.Event) {
        queue.async { [weak self] in
            guard let self else { return }
            switch event {
            case .initialLoading:
                if firstReload {
                    listState = .loading
                }
            case .initialLoadingFailed:
                showSpamFooter(transactionsManagementState: transactionsManagementStore.state)
            case let .initialLoaded(events, hasMore):
                self.events = events
                resetSectionsCalculationState()
                let transactionsManagementState = transactionsManagementStore.state
                let spamEvents = filterSpamEvents(events, transactionsManagementState: transactionsManagementState)

                if !spamEvents.isEmpty {
                    // Found spam events, show them with footer
                    showSpamEvents(spamEvents, transactionsManagementState: transactionsManagementState)
                    showSpamFooterWithEvents(transactionsManagementState: transactionsManagementState)
                } else if hasMore, !hasTriedOneExtraLoad {
                    // No spam found but more events available, try ONE more load
                    hasTriedOneExtraLoad = true
                    listState = .content(State.Content(sections: []), pagination: .loading)
                } else {
                    // No spam found and (no more events OR already tried one extra load), show footer
//          showSpamFooter(transactionsManagementState: transactionsManagementState)
                }
                firstReload = false
            case let .pageLoaded(events, _):
                guard !spamPaginationStopped else { return }

                var newEvents = [HistoryEvent]()
                for event in events {
                    if !self.events.contains(where: { $0.eventId == event.eventId }) {
                        newEvents.append(event)
                    }
                }
                self.events += newEvents

                let transactionsManagementState = transactionsManagementStore.state
                let newSpamEvents = filterSpamEvents(newEvents, transactionsManagementState: transactionsManagementState)

                if !newSpamEvents.isEmpty {
                    // Found spam in new page, show them with footer (don't continue loading)
                    let sections = calculateSections(sections: listState.sections, events: newSpamEvents)
                    update(withEvents: newSpamEvents)
                    listState = .content(State.Content(sections: sections), pagination: .none)
                    showSpamFooterWithEvents(transactionsManagementState: transactionsManagementState)
                } else {
                    // No spam in this page, stop loading and show footer (we only try once)
//          showSpamFooter(transactionsManagementState: transactionsManagementState)
                }
            case .pageLoadingFailed:
                listState = .content(State.Content(sections: listState.sections), pagination: .error)
            default:
                break
            }
        }
    }

    // MARK: - Helper Methods (copied from main ViewModel)

    private func didUpdateListState() {
        updateList()
    }

    private func updateList() {
        let snapshot = createSnapshot(listState: listState)
        let state: HistoryList.State = {
            switch listState {
            case .loading:
                return .loading
            case let .content(content, _):
                return content.isEmpty ? .empty : .content
            }
        }()
        let paginationCellConfiguration = mapPaginationCellConfiguration(listState)
        DispatchQueue.main.async { [weak self] in
            self?.paginationCellConfiguration = paginationCellConfiguration
            self?.snapshotUpdate?(snapshot)
            self?.didUpdateState?(state)
        }
    }

    private func update(withEvents events: [HistoryEvent]) {
        let configurations = mapHistoryEventsCellConfigurations(events, relativeDate: relativeDate)
        DispatchQueue.main.async {
            self.eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
        }
    }

    private func calculateSections(sections: [HistoryList.Section], events: [HistoryEvent]) -> [HistoryList.Section] {
        return calculateSections(events: events, sections: sections, relativeDate: relativeDate)
    }

    private var eventsMap = [AccountEvent.EventID: HistoryEvent]()
    private var sectionsMap = [HistoryList.Section.ID: Int]()

    private func resetSectionsCalculationState() {
        relativeDate = Date()
        eventsMap = [:]
        sectionsMap = [:]
        eventCellConfigurations = [:]
        paginationCellConfiguration = .init(state: .none)
    }

    private func calculateSections(events: [HistoryEvent], sections: [HistoryList.Section], relativeDate: Date) -> [HistoryList.Section] {
        var sections = sections
        for event in events {
            eventsMap[event.eventId] = event
            guard let sectionDate = getEventSectionData(event: event, relativeDate: relativeDate) else { continue }

            if let sectionIndex = sectionsMap[sectionDate], sections.count > sectionIndex {
                let section = sections[sectionIndex]
                var sectionEvents = section.events

                let isEventExist = eventsMap[event.identifier] != nil
                if isEventExist, let index = sectionEvents.firstIndex(where: { $0.eventId == event.eventId }) {
                    sectionEvents.remove(at: index)
                    sectionEvents.insert(event, at: index)
                } else {
                    if let indexToInsert = sectionEvents.firstIndex(where: { event.date > $0.date }) {
                        sectionEvents.insert(event, at: indexToInsert)
                    } else {
                        sectionEvents.append(event)
                    }
                }
                let updatedSection = HistoryList.Section(id: section.date, events: sectionEvents)
                sections.remove(at: sectionIndex)
                sections.insert(updatedSection, at: sectionIndex)
            } else {
                let section = HistoryList.Section(id: sectionDate, events: [event])
                if let indexToInsert = sections.firstIndex(where: { section.date > $0.date }) {
                    sections.insert(section, at: indexToInsert)
                } else {
                    sections.append(section)
                }
                sectionsMap = Dictionary(
                    sections.enumerated().map { ($0.element.date, $0.offset) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
        }
        return sections
    }

    private func mapPaginationCellConfiguration(_ state: State) -> HistoryListPaginationCell.Model {
        switch state {
        case .loading:
            return HistoryListPaginationCell.Model(state: .none)
        case let .content(_, pagination):
            switch pagination {
            case .none:
                return HistoryListPaginationCell.Model(state: .none)
            case .loading:
                return HistoryListPaginationCell.Model(state: .loading)
            case .error:
                return HistoryListPaginationCell.Model(
                    state: .error(title: TKLocales.State.failed, retryButtonAction: { [weak self] in
                        self?.historyLoader.loadNext()
                    })
                )
            case let .spamFooter(date):
                return HistoryListPaginationCell.Model(state: .spamFooter(text: date))
            }
        }
    }

    private func createSnapshot(listState: State) -> HistoryList.Snapshot {
        var snapshot = HistoryList.Snapshot()
        switch listState {
        case .loading:
            snapshot.appendSections([.shimmer])
            snapshot.appendItems([.shimmer], toSection: .shimmer)
        case let .content(content, pagination):
            if content.isEmpty {
                if case .spamFooter = pagination {
                    // Show footer even when no spam events
                    snapshot.appendSections([.pagination])
                    snapshot.appendItems([.pagination], toSection: .pagination)
                } else {
                    snapshot.appendSections([.empty])
                    snapshot.appendItems([.empty], toSection: .empty)
                }
            } else {
                for section in content.sections {
                    let sectionId = HistoryList.SnapshotSection.events(section.date)
                    snapshot.appendSections([sectionId])
                    var eventIdsSet = Set<String>()
                    let eventIds: [HistoryList.SnapshotItem] = section.events.compactMap {
                        guard !eventIdsSet.contains($0.identifier) else { return nil }
                        eventIdsSet.insert($0.identifier)
                        return HistoryList.SnapshotItem.event($0.identifier)
                    }
                    snapshot.appendItems(eventIds, toSection: sectionId)
                    if #available(iOS 15.0, *) {
                        snapshot.reconfigureItems(eventIds)
                    } else {
                        snapshot.reloadItems(eventIds)
                    }
                }
                switch pagination {
                case .loading, .error, .spamFooter:
                    snapshot.appendSections([.pagination])
                    snapshot.appendItems([.pagination], toSection: .pagination)
                default: break
                }
            }
        }
        return snapshot
    }

    // MARK: - Additional helper methods (simplified versions from main ViewModel)

    private func mapHistoryEventsCellConfigurations(_ events: [HistoryEvent], relativeDate: Date) -> [AccountEvent.EventID: HistoryCell.Model] {
        let isSecureMode = appSettingsStore.getState().isSecureMode
        var configurations = [AccountEvent.EventID: HistoryCell.Model]()

        for event in events {
            let eventPeriod = EventPeriod.eventPeriod(date: event.date, relativeDate: relativeDate)
            switch event {
            case let .tonAccountEvent(accountEvent):
                configurations[event.identifier] = mapEventCellConfiguration(
                    event: accountEvent,
                    eventPeriod: eventPeriod,
                    isSecure: isSecureMode
                )
            case let .tronEvent(tronTransaction):
                guard let tronAddress = wallet.tron?.address else { continue }
                configurations[event.identifier] = mapTronEventCellConfiguration(
                    event: tronTransaction,
                    owner: tronAddress,
                    eventPeriod: eventPeriod,
                    isSecure: isSecureMode
                )
            }
        }
        return configurations
    }

    private func mapEventCellConfiguration(event: AccountEvent, eventPeriod: EventPeriod, isSecure: Bool) -> HistoryCell.Model {
        dateFormatter.dateFormat = eventPeriod.dateFormat

        let eventModel = accountEventMapper.mapEvent(
            event,
            nftManagmentStore: nftManagmentStore,
            transactionManagementStore: transactionsManagementStore,
            eventDate: event.date,
            accountEventRightTopDescriptionProvider: HistoryAccountEventRightTopDescriptionProvider(
                dateFormatter: dateFormatter
            ),
            network: wallet.network,
            nftProvider: { [weak self] address in
                guard let self else { return nil }
                return try? self.nftService.getNFT(address: address, network: self.wallet.network)
            },
            decryptedCommentProvider: { [weak self, wallet] payload in
                guard !isSecure else { return nil }
                return self?.decryptedCommentStore.getDecryptedComment(wallet: wallet, payload: payload, eventId: event.eventId)
            }
        )

        return historyEventMapper.mapEvent(
            eventModel,
            isSecureMode: isSecure,
            nftAction: { [weak self, wallet] address in
                self?.didSelectNFT?(wallet, address)
            },
            encryptedCommentAction: { [weak self, wallet] payload in
                self?.didSelectEncryptedComment?(wallet, payload, eventModel.eventId)
            },
            tapAction: { [weak self] accountEventDetailsEvent in
                self?.didSelectEvent?(.tonEvent(accountEventDetailsEvent))
            }
        )
    }

    private func mapTronEventCellConfiguration(event: TronTransaction, owner: TronSwift.Address, eventPeriod: EventPeriod, isSecure: Bool) -> HistoryCell.Model {
        return tronEventMapper.mapEvent(
            event,
            owner: owner,
            dateFormat: eventPeriod.dateFormat,
            tapAction: { [weak self] in
                self?.didSelectEvent?(.tronEvent(event))
            }
        )
    }

    private func getEventSectionData(event: HistoryEvent, relativeDate: Date) -> Date? {
        let calendar = Calendar.current
        let eventPeriod = EventPeriod.eventPeriod(date: event.date, relativeDate: relativeDate)
        let dateComponents = calendar.dateComponents(eventPeriod.calendarComponents, from: event.date)
        return calendar.date(from: dateComponents)
    }

    private func formatEventSectionDate(_ date: Date) -> String? {
        let calendar = Calendar.current
        let currentDate = Date()
        if calendar.isDateInToday(date) {
            return TKLocales.Dates.today
        } else if calendar.isDateInYesterday(date) {
            return TKLocales.Dates.yesterday
        } else if calendar.isDate(date, equalTo: currentDate, toGranularity: .month) {
            dateFormatter.dateFormat = "d MMMM"
        } else if calendar.isDate(date, equalTo: currentDate, toGranularity: .year) {
            dateFormatter.dateFormat = "LLLL"
        } else {
            dateFormatter.dateFormat = "LLLL y"
        }
        return dateFormatter.string(from: date).capitalized
    }

    private func didGetAppSettingsStoreEvent(_ event: AppSettingsStore.Event) {
        switch event {
        case .didUpdateIsSecureMode:
            queue.async { [weak self] in
                guard let self else { return }
                reload(force: false)
            }
        default: break
        }
    }

    private func didUpdateNFTsState() {
        queue.async { [weak self] in
            guard let self else { return }
            reload(force: false)
        }
    }

    private func didGetDecryptedCommentStoreEvent(_ event: DecryptedCommentStore.Event) {
        switch event {
        case let .didDecryptComment(eventId, wallet):
            guard wallet == self.wallet else { return }
            queue.async { [weak self] in
                guard let self else { return }
                guard let event = eventsMap[eventId],
                      case let .tonAccountEvent(tonAccountEvent) = event else { return }
                let eventPeriod = EventPeriod.eventPeriod(date: tonAccountEvent.date, relativeDate: relativeDate)
                let isSecureMode = appSettingsStore.getState().isSecureMode
                let configuration = mapEventCellConfiguration(
                    event: tonAccountEvent,
                    eventPeriod: eventPeriod,
                    isSecure: isSecureMode
                )
                DispatchQueue.main.async {
                    self.eventCellConfigurations[event.identifier] = configuration
                }
                updateList()
            }
        }
    }
}

extension SpamHistoryListViewModelImplementation: TransactionsManagement.Store.Observer {
    func didGetTransactionsManagementStore(_ store: TransactionsManagement.Store, event: TransactionsManagement.Store.Event) {
        queue.async { [weak self] in
            switch event {
            case .updateStates:
                guard let self else { return }
                reload(force: false)
            default:
                break
            }
        }
    }
}

private enum EventPeriod {
    case recent
    case thisYear
    case previousYear

    var dateFormat: String {
        switch self {
        case .recent:
            "HH:mm"
        case .thisYear:
            "dd MMM, HH:mm"
        case .previousYear:
            "dd MMM yyyy, HH:mm"
        }
    }

    var calendarComponents: Set<Calendar.Component> {
        switch self {
        case .recent:
            [.year, .month, .day]
        case .thisYear:
            [.year, .month]
        case .previousYear:
            [.year, .month]
        }
    }

    static func eventPeriod(date: Date, relativeDate: Date) -> EventPeriod {
        let calendar = Calendar.current
        if calendar.isDateInToday(date)
            || calendar.isDateInYesterday(date)
            || calendar.isDate(date, equalTo: relativeDate, toGranularity: .month)
        {
            return .recent
        } else if calendar.isDate(date, equalTo: relativeDate, toGranularity: .year) {
            return .thisYear
        } else {
            return .previousYear
        }
    }
}
