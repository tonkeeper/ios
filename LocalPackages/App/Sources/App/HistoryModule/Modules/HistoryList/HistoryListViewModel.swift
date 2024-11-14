import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol HistoryListModuleOutput: AnyObject {
  var didUpdateState: ((_ hasEvents: Bool) -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)? { get set }
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload, _ eventId: String) -> Void)? { get set }
}

protocol HistoryListViewModel: AnyObject {
  var eventHandler: ((_ event: HistoryListViewModelEvent) -> Void)? { get set }
  
  func viewDidLoad()
  func loadNextPage()
  func reload()
  func getEventCellConfiguration(eventID: HistoryList.EventID) -> HistoryCell.Model?
  func getPaginationCellConfiguration() -> HistoryListPaginationCell.Model
  func getSectionHeaderTitle(sectionID: HistoryList.Section.ID) -> String?
}

enum HistoryListViewModelEvent {
  case snapshotUpdate(HistoryList.Snapshot)
}

final class HistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput {
  
  // MARK: - HistoryListModuleOutput
  
  var didUpdateState: ((_ hasEvents: Bool) -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)?
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload, _ eventId: String) -> Void)?
  
  // MARK: - HistoryListViewModel
  
  var eventHandler: ((HistoryListViewModelEvent) -> Void)?

  func viewDidLoad() {
    appSettingsStore.addObserver(self) { observer, event in
      observer.didGetAppSettingsStoreEvent(event)
    }
    decryptedCommentStore.addObserver(self) { observer, event in
      observer.didGetDecryptedCommentStoreEvent(event)
    }
    paginationLoader.eventHandler = { [weak self] event in
      self?.didGetPaginationLoaderEvent(event)
    }

    backgroundUpdate.addEventObserver(self) { observer, wallet, _ in
      guard wallet == observer.wallet else { return }
      observer.queue.async {
        observer.paginationLoader.reload()
      }
    }

    nftManagmentStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateState(let wallet):
        guard wallet == observer.wallet else {
          return
        }

        observer.didUpdateNFTsState()
      }
    }
    setInitialState()
    paginationLoader.reload()
  }
  
  func loadNextPage() {
    guard isLoadNextAvailable else { return }
    paginationLoader.loadNext()
  }
  
  func reload() {
    paginationLoader.reload()
  }
  
  func getEventCellConfiguration(eventID: HistoryList.EventID) -> HistoryCell.Model? {
    eventCellConfigurations[eventID]
  }
  
  func getPaginationCellConfiguration() -> HistoryListPaginationCell.Model {
    paginationCellConfiguration
  }
  
  func getSectionHeaderTitle(sectionID: HistoryList.Section.ID) -> String? {
    mapEventsSectionDate(sectionID)
  }
  
  // MARK: - State
  
  private let queue = DispatchQueue(label: "HistoryListViewModelImplementationQueue")
  private var relativeDate = Date()
  private var events = [AccountEvent]()
  private var eventsMap = [AccountEvent.EventID: AccountEvent]()
  private var sections = [HistoryList.Section]()
  private var sectionsMap = [HistoryList.Section.ID: Int]()
  private var hasEvents = true {
    didSet {
      let hasEvents = hasEvents
      DispatchQueue.main.async {
        self.didUpdateState?(hasEvents)
      }
    }
  }
  
  private var snapshot = HistoryList.Snapshot()
  private var isLoadNextAvailable = false
  private var eventCellConfigurations = [AccountEvent.EventID: HistoryCell.Model]()
  private var paginationCellConfiguration = HistoryListPaginationCell.Model(state: .none)
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let paginationLoader: HistoryPaginationLoader
  private let appSettingsStore: AppSettingsStore
  private let backgroundUpdate: BackgroundUpdate
  private let decryptedCommentStore: DecryptedCommentStore
  private let nftService: NFTService
  private let cacheProvider: HistoryListCacheProvider
  private let dateFormatter: DateFormatter
  private let accountEventMapper: AccountEventMapper
  private let historyEventMapper: HistoryEventMapper
  private let nftManagmentStore: WalletNFTsManagementStore

  // MARK: - Init
  
  init(wallet: Wallet,
       paginationLoader: HistoryPaginationLoader,
       appSettingsStore: AppSettingsStore,
       backgroundUpdate: BackgroundUpdate,
       decryptedCommentStore: DecryptedCommentStore,
       nftService: NFTService,
       cacheProvider: HistoryListCacheProvider,
       dateFormatter: DateFormatter,
       accountEventMapper: AccountEventMapper,
       historyEventMapper: HistoryEventMapper,
       nftManagmentStore: WalletNFTsManagementStore) {
    self.wallet = wallet
    self.paginationLoader = paginationLoader
    self.appSettingsStore = appSettingsStore
    self.backgroundUpdate = backgroundUpdate
    self.decryptedCommentStore = decryptedCommentStore
    self.nftService = nftService
    self.cacheProvider = cacheProvider
    self.dateFormatter = dateFormatter
    self.accountEventMapper = accountEventMapper
    self.historyEventMapper = historyEventMapper
    self.nftManagmentStore = nftManagmentStore
  }

  private func setInitialState() {
    let (eventCellConfigurations, snapshot) = queue.sync {
      let snapshot: HistoryList.Snapshot
      var eventCellConfigurations = [AccountEvent.EventID: HistoryCell.Model]()
      if let cachedEvents = try? cacheProvider.getCache(wallet: wallet),
         !cachedEvents.isEmpty {
        handleEvents(cachedEvents)
        snapshot = self.snapshot.eventsSnapshot(
          sections: sections,
          hasPagination: false)
        eventCellConfigurations = mapEventsCellConfigurations(events: cachedEvents)
      } else {
        snapshot = self.snapshot.shimmerSnapshot()
      }
      self.snapshot = snapshot
      return (eventCellConfigurations, snapshot)
    }
    self.eventCellConfigurations = eventCellConfigurations
    eventHandler?(.snapshotUpdate(snapshot))
  }
  
  private func resetState() {
    relativeDate = Date()
    events = [AccountEvent]()
    eventsMap = [AccountEvent.EventID: AccountEvent]()
    sections = [HistoryList.Section]()
    sectionsMap = [HistoryList.Section.ID: Int]()
  }
  
  private func didGetPaginationLoaderEvent(_ event: HistoryPaginationLoader.Event) {
    queue.async { [weak self] in
      guard let self else { return }
      switch event {
      case .initialLoading:
        break
      case .initialLoadingFailed:
        resetState()
        hasEvents = false
        try? cacheProvider.setCache(events: [], wallet: wallet)
      case .initialLoaded(let accountEvents):
        resetState()
        hasEvents = !accountEvents.events.isEmpty
        handleLoadedEvents(accountEvents)
      case .pageLoading:
        break
      case .pageLoadingFailed:
        handlePageLoadingFailed()
      case .pageLoaded(let accountEvents):
        handleLoadedEvents(accountEvents)
      }
    }
  }
  
  private func didGetAppSettingsStoreEvent(_ event: AppSettingsStore.Event) {
    switch event {
    case .didUpdateIsSecureMode:
      queue.async { [weak self] in
        guard let self else { return }
        let configurations = mapEventsCellConfigurations(events: events)
        let snapshot = snapshot.reloadAllItemsSnapshot()
        DispatchQueue.main.async {
          self.eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
          self.eventHandler?(.snapshotUpdate(snapshot))
        }
      }
    default: break
    }
  }

  private func didUpdateNFTsState() {
    queue.async { [weak self] in
      guard let self else { return }
      let configurations = mapEventsCellConfigurations(events: events)
      let snapshot = snapshot.reloadAllItemsSnapshot()
      DispatchQueue.main.async {
        self.eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
        self.eventHandler?(.snapshotUpdate(snapshot))
      }
    }
  }

  private func didGetDecryptedCommentStoreEvent(_ event: DecryptedCommentStore.Event) {
    switch event {
    case .didDecryptComment(let eventId, let wallet):
      guard wallet == self.wallet else { return }
      queue.async { [weak self] in
        guard let self else { return }
        guard let event = eventsMap[eventId] else { return }
        let eventPeriod = calculateEventPeriod(event: event, relativeDate: relativeDate)
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let configuration = mapEventCellConfiguration(
          event: event,
          eventPeriod: eventPeriod,
          isSecure: isSecureMode
        )
        let snapshot = snapshot.reloadEventSnapshot(eventId: eventId)
        DispatchQueue.main.async {
          self.eventCellConfigurations[eventId] = configuration
          self.eventHandler?(.snapshotUpdate(snapshot))
        }
      }
    }
  }
  
  private func handleLoadedEvents(_ events: AccountEvents) {
    let hasMore = events.nextFrom != 0
    self.events = self.events + events.events
    
    try? cacheProvider.setCache(events: self.events, wallet: wallet)
    handleEvents(events.events)
    
    let configurations = mapEventsCellConfigurations(events: events.events)
    
    let snapshot = snapshot.eventsSnapshot(sections: sections, hasPagination: hasMore)
    self.snapshot = snapshot
    
    DispatchQueue.main.async {
      self.eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
      self.isLoadNextAvailable = hasMore
      self.paginationCellConfiguration = hasMore ? .init(state: .loading) : .init(state: .none)
      self.eventHandler?(.snapshotUpdate(snapshot))
    }
  }
  
  private func handlePageLoadingFailed() {
    let snapshot = snapshot.reloadPaginationSnapshot()
    self.snapshot = snapshot
    
    let paginationCellConfiguration = HistoryListPaginationCell.Model(
      state: .error(
        title: TKLocales.State.failed,
        retryButtonAction: { [weak self] in
          self?.paginationLoader.loadNext()
        }
      )
    )
    
    DispatchQueue.main.async {
      self.paginationCellConfiguration = paginationCellConfiguration
      self.isLoadNextAvailable = false
      self.eventHandler?(.snapshotUpdate(snapshot))
    }
  }
  
  private func handleEvents(_ events: [AccountEvent]) {
    for event in events {
      let isEventRepeat = eventsMap[event.eventId] != nil
      eventsMap[event.eventId] = event
      let eventPeriod = calculateEventPeriod(event: event, relativeDate: relativeDate)
      guard let sectionDate = calculateEventSectionDate(event: event, eventPeriod: eventPeriod) else { continue }
      
      if let sectionIndex = sectionsMap[sectionDate],
         sections.count > sectionIndex {
        let section = sections[sectionIndex]
        var updatedEvents = section.events
        if isEventRepeat {
          if let index = updatedEvents.firstIndex(where: { $0.eventId == event.eventId }) {
            updatedEvents.remove(at: index)
            updatedEvents.insert(event, at: index)
          }
        } else {
          if let indexToInsert = updatedEvents.firstIndex(where: { event.date > $0.date }) {
            updatedEvents.insert(event, at: indexToInsert)
          } else {
            updatedEvents.append(event)
          }
        }
        let updatedSection = HistoryList.Section(
          id: section.date,
          events: updatedEvents
        )
        sections.remove(at: sectionIndex)
        sections.insert(updatedSection, at: sectionIndex)
      } else {
        let section = HistoryList.Section(
          id: sectionDate,
          events: [event]
        )
        
        if let indexToInsert = sections.firstIndex(where: { section.date > $0.date }) {
          sections.insert(section, at: indexToInsert)
        } else {
          sections.append(section)
        }
        sectionsMap = Dictionary(uniqueKeysWithValues: sections.enumerated().map {
          ($0.element.date, $0.offset) }
        )
      }
    }
  }
  
  private func mapEventsCellConfigurations(events: [AccountEvent]) -> [AccountEvent.EventID: HistoryCell.Model] {
    let isSecureMode = appSettingsStore.getState().isSecureMode
    var configurations = [String: HistoryCell.Model]()
    for event in events {
      let eventPeriod = calculateEventPeriod(event: event, relativeDate: relativeDate)
      configurations[event.eventId] = mapEventCellConfiguration(
        event: event,
        eventPeriod: eventPeriod,
        isSecure: isSecureMode
      )
    }
    return configurations
  }
  
  private func mapEventCellConfiguration(event: AccountEvent, 
                                         eventPeriod: EventPeriod,
                                         isSecure: Bool) -> HistoryCell.Model {
    dateFormatter.dateFormat = eventPeriod.dateFormat
    
    let eventModel = accountEventMapper.mapEvent(
      event,
      nftManagmentStore: nftManagmentStore,
      eventDate: event.date,
      accountEventRightTopDescriptionProvider: HistoryAccountEventRightTopDescriptionProvider(
        dateFormatter: dateFormatter
      ),
      isTestnet: wallet.isTestnet,
      nftProvider: { [weak self] address in
        guard let self else { return nil }
        return try? self.nftService.getNFT(address: address, isTestnet: self.wallet.isTestnet)
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
        self?.didSelectEvent?(accountEventDetailsEvent)
      }
    )
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
  }

  private func calculateEventSectionDate(event: AccountEvent, eventPeriod: EventPeriod) -> Date? {
    let dateComponents = Calendar.current.dateComponents(eventPeriod.calendarComponents, from: event.date)
    return Calendar.current.date(from: dateComponents)
  }
  
  private func calculateEventPeriod(event: AccountEvent, relativeDate: Date) -> EventPeriod {
    let calendar = Calendar.current
    if calendar.isDateInToday(event.date)
        || calendar.isDateInYesterday(event.date)
        || calendar.isDate(event.date, equalTo: relativeDate, toGranularity: .month) {
      return .recent
    } else if calendar.isDate(event.date, equalTo: relativeDate, toGranularity: .year) {
      return .thisYear
    } else {
      return .previousYear
    }
  }
  
  private func mapEventsSectionDate(_ date: Date) -> String? {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return TKLocales.Dates.today
    } else if calendar.isDateInYesterday(date) {
      return TKLocales.Dates.yesterday
    } else if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
      dateFormatter.dateFormat = "d MMMM"
    } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
      dateFormatter.dateFormat = "LLLL"
    } else {
      dateFormatter.dateFormat = "LLLL y"
    }
    return dateFormatter.string(from: date).capitalized
  }
}

private extension HistoryList.Snapshot {
  func shimmerSnapshot() -> Self {
    var snapshot = self
    snapshot.deleteAllItems()
    snapshot.appendSections([.shimmer])
    snapshot.appendItems([.shimmer], toSection: .shimmer)
    return snapshot
  }
  
  func eventsSnapshot(sections: [HistoryList.Section],
                      hasPagination: Bool) -> Self {
    var snapshot = self
    snapshot.deleteAllItems()
    for section in sections {
      let sectionIdentifier = HistoryList.SnapshotSection.events(section.date)
      snapshot.appendSections([sectionIdentifier])
      let eventIdentifiers = section.events.map { HistoryList.SnapshotItem.event($0.eventId) }
      snapshot.appendItems(eventIdentifiers, toSection: sectionIdentifier)
      if #available(iOS 15.0, *) {
        snapshot.reconfigureItems(eventIdentifiers)
      } else {
        snapshot.reloadItems(eventIdentifiers)
      }
    }
    if hasPagination {
      snapshot.appendSections([.pagination])
      snapshot.appendItems([.pagination], toSection: .pagination)
    }
    return snapshot
  }
  
  func reloadAllItemsSnapshot() -> Self {
    var snapshot = self
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    return snapshot
  }
  
  func reloadEventSnapshot(eventId: AccountEvent.EventID) -> Self {
    var snapshot = self
    let item = HistoryList.SnapshotItem.event(eventId)
    guard snapshot.indexOfItem(item) != nil else {
      return snapshot
    }
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems([item])
    } else {
      snapshot.reloadItems([item])
    }
    return snapshot
  }
  
  func reloadPaginationSnapshot() -> Self {
    var snapshot = self
    guard snapshot.indexOfItem(.pagination) != nil else {
      return snapshot
    }
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems([.pagination])
    } else {
      snapshot.reloadItems([.pagination])
    }
    return snapshot
  }
}
