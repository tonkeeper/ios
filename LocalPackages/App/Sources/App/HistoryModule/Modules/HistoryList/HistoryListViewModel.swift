import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol HistoryListModuleOutput: AnyObject {
  var didUpdateState: ((_ hasEvents: Bool) -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)? { get set }
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload) -> Void)? { get set }
}

enum HistoryListViewModelEvent {
  case snapshotUpdate(HistoryListViewController.Snapshot)
}

protocol HistoryListViewModel: AnyObject {
  var eventHandler: ((_ event: HistoryListViewModelEvent) -> Void)? { get set }
  
  func viewDidLoad()
  func getEventCellConfiguration(identifier: String) -> HistoryCell.Model?
  func getPaginationCellConfiguration() -> HistoryListPaginationCell.Model
  func getSectionHeader(date: Date) -> String?
  func loadNextPage()
}

final class HistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput {
  
  struct EventsSection {
    let date: Date
    let events: [AccountEvent]
  }
  
  var didUpdateState: ((_ hasEvents: Bool) -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)?
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload) -> Void)?
  
  var eventHandler: ((HistoryListViewModelEvent) -> Void)?

  func viewDidLoad() {
    appSettingsStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateIsSecureMode:
        observer.queue.async {
          observer.didUpdateSecureMode()
        }
      default:
        break
      }
    }
    paginationLoader.eventHandler = { [weak self] event in
      self?.queue.async {
        self?.didGetLoaderEvent(event: event)
      }
    }
    paginationLoader.reload()
    setInitialState()
  }
  
  func getEventCellConfiguration(identifier: String) -> HistoryCell.Model? {
    eventCellConfigurations[identifier]
  }
  
  func getPaginationCellConfiguration() -> HistoryListPaginationCell.Model {
    paginationCellConfiguration
  }
  
  func getSectionHeader(date: Date) -> String? {
    mapEventsSectionDate(date)
  }
  
  func loadNextPage() {
    guard isLoadNextAvaiable else { return }
    paginationLoader.loadNext()
  }
  
  private let queue = DispatchQueue(label: "HistoryListViewModelImplementationQueue")
  private var relativeDate = Date()
  private var events = [AccountEvent]()
  private var sections = [EventsSection]()
  private var sectionsOrder = [Date: Int]()

  private var snapshot = HistoryListViewController.Snapshot() {
    didSet {
      eventHandler?(.snapshotUpdate(snapshot))
    }
  }
  private var eventCellConfigurations = [String: HistoryCell.Model]()
  private var paginationCellConfiguration = HistoryListPaginationCell.Model(state: .none)
  private var isLoadNextAvaiable = false

  private let wallet: Wallet
  private let paginationLoader: HistoryPaginationLoader
  private let appSettingsStore: AppSettingsV3Store
  private let nftService: NFTService
  private let cacheProvider: HistoryListCacheProvider
  private let dateFormatter: DateFormatter
  private let accountEventMapper: AccountEventMapper
  private let historyEventMapper: HistoryEventMapper
  
  init(wallet: Wallet,
       paginationLoader: HistoryPaginationLoader,
       appSettingsStore: AppSettingsV3Store,
       nftService: NFTService,
       cacheProvider: HistoryListCacheProvider,
       dateFormatter: DateFormatter,
       accountEventMapper: AccountEventMapper,
       historyEventMapper: HistoryEventMapper) {
    self.wallet = wallet
    self.paginationLoader = paginationLoader
    self.appSettingsStore = appSettingsStore
    self.nftService = nftService
    self.cacheProvider = cacheProvider
    self.dateFormatter = dateFormatter
    self.accountEventMapper = accountEventMapper
    self.historyEventMapper = historyEventMapper
  }

  private func setInitialState() {
    if let cachedEvents = try? cacheProvider.getCache(wallet: wallet),
    !cachedEvents.isEmpty {
      var configurations = [String: HistoryCell.Model]()
      var snapshot = HistoryListViewController.Snapshot()
      queue.sync {
        handleEvents(cachedEvents, sections: &sections, sectionsOrder: &sectionsOrder, relativeDate: relativeDate)
        configurations = updateEventConfigurations(events: cachedEvents, relativeDate: relativeDate)
        snapshot = createEventsSnapshot(hasPagination: false)
      }
      
      eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
      self.snapshot = snapshot
    } else {
      self.snapshot = createShimmerSnapshot()
    }
  }
  
  private func createShimmerSnapshot() -> HistoryListViewController.Snapshot {
    var snapshot = HistoryListViewController.Snapshot()
    snapshot.appendSections([.shimmer])
    snapshot.appendItems([.shimmer], toSection: .shimmer)
    return snapshot
  }
  
  private func createEventsSnapshot(hasPagination: Bool) -> HistoryListViewController.Snapshot {
    var snapshot = HistoryListViewController.Snapshot()
    for section in sections {
      let snapshotSection = HistoryListViewController.Section.events(HistoryListEventsSection(date: section.date))
      snapshot.appendSections([snapshotSection])
      snapshot.appendItems(section.events.map { .event(identifier: $0.eventId) }, toSection: snapshotSection)
    }
    if hasPagination {
      snapshot.appendSections([.pagination])
      snapshot.appendItems([.pagination], toSection: .pagination)
    }
    return snapshot
  }
  
  private func reconfigureItemsSnapshot(snapshot: HistoryListViewController.Snapshot) -> HistoryListViewController.Snapshot {
    var snapshot = snapshot
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    return snapshot
  }
  
  private func reconfigurePaginationSnapshot(snapshot: HistoryListViewController.Snapshot) -> HistoryListViewController.Snapshot {
    var snapshot = snapshot
    snapshot.reloadSections([.pagination])
    return snapshot
  }
  
  private func didGetLoaderEvent(event: HistoryPaginationLoader.Event) {
    switch event {
    case .initialLoading:
      break
    case .initialLoadingFailed:
      events = []
      sections = []
      sectionsOrder = [:]
      try? cacheProvider.setCache(events: [], wallet: wallet)
      DispatchQueue.main.async {
        self.didUpdateState?(false)
      }
    case .initialLoaded(let accountEvents):
      events = []
      sections = []
      sectionsOrder = [:]
      handleLoadedEvents(accountEvents)
      DispatchQueue.main.async {
        self.didUpdateState?(!accountEvents.events.isEmpty)
      }
    case .pageLoading:
      break
    case .pageLoadingFailed:
      handlePageLoadingFailed()
    case .pageLoaded(let accountEvents):
      handleLoadedEvents(accountEvents)
    }
  }

  private func didUpdateSecureMode() {
    let configurations = updateEventConfigurations(events: events, relativeDate: relativeDate)
    let snapshot = reconfigureItemsSnapshot(snapshot: snapshot)
    DispatchQueue.main.async {
      self.eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
      self.snapshot = snapshot
    }
  }
  
  private func handleLoadedEvents(_ events: AccountEvents) {
    let hasMore = events.nextFrom != 0
    self.events = self.events + events.events
    try? cacheProvider.setCache(events: self.events, wallet: wallet)
    handleEvents(events.events, sections: &sections, sectionsOrder: &sectionsOrder, relativeDate: relativeDate)
    let configurations = updateEventConfigurations(events: events.events, relativeDate: relativeDate)
    let snapshot = createEventsSnapshot(hasPagination: hasMore)
    DispatchQueue.main.async {
      self.eventCellConfigurations.merge(configurations, uniquingKeysWith: { $1 })
      if hasMore {
        self.paginationCellConfiguration = HistoryListPaginationCell.Model(state: .loading)
        self.isLoadNextAvaiable = true
      } else {
        self.paginationCellConfiguration = HistoryListPaginationCell.Model(state: .none)
        self.isLoadNextAvaiable = false
      }
      self.snapshot = snapshot
    }
  }
  
  private func handlePageLoadingFailed() {
    let snapshot = reconfigurePaginationSnapshot(snapshot: snapshot)
    DispatchQueue.main.async {
      self.paginationCellConfiguration = HistoryListPaginationCell.Model(
        state: .error(
          title: TKLocales.Actions.failed,
          retryButtonAction: { [weak self] in
            self?.paginationLoader.loadNext()
          }
        )
      )
      self.isLoadNextAvaiable = false
      self.snapshot = snapshot
    }
  }

  private func handleEvents(_ events: [AccountEvent],
                            sections: inout [EventsSection],
                            sectionsOrder: inout [Date: Int],
                            relativeDate: Date) {
    for event in events {
      let eventPeriod = calculateEventPeriod(event: event, relativeDate: relativeDate)
      guard let sectionDate = calculateEventSectionDate(event: event, eventPeriod: eventPeriod) else { continue }
      
      if let sectionIndex = sectionsOrder[sectionDate],
         sections.count > sectionIndex {
        let section = sections[sectionIndex]
        var updatedEvents = section.events
        if let indexToInsert = updatedEvents.firstIndex(where: { event.date > $0.date }) {
          updatedEvents.insert(event, at: indexToInsert)
        } else {
          updatedEvents.append(event)
        }
        let updatedSection = EventsSection(
          date: section.date,
          events: updatedEvents
        )
        sections.remove(at: sectionIndex)
        sections.insert(updatedSection, at: sectionIndex)
      } else {
        let section = EventsSection(
          date: sectionDate,
          events: [event]
        )
        
        if let indexToInsert = sections.firstIndex(where: { section.date > $0.date }) {
          sections.insert(section, at: indexToInsert)
        } else {
          sections.append(section)
        }
        sectionsOrder = Dictionary(uniqueKeysWithValues: sections.enumerated().map {
          ($0.element.date, $0.offset) }
        )
      }
    }
  }
  
  private func updateEventConfigurations(events: [AccountEvent], relativeDate: Date) -> [String: HistoryCell.Model] {
    var configurations = [String: HistoryCell.Model]()
    for event in events {
      let eventPeriod = calculateEventPeriod(event: event, relativeDate: relativeDate)
      configurations[event.eventId] = mapEventCellConfiguration(mapEvent(event, eventPeriod: eventPeriod))
    }
    return configurations
  }

  private func mapEvent(_ event: AccountEvent, eventPeriod: EventPeriod) -> AccountEventModel {
    dateFormatter.dateFormat = eventPeriod.dateFormat

    let eventModel = accountEventMapper.mapEvent(
      event,
      eventDate: event.date,
      accountEventRightTopDescriptionProvider: HistoryAccountEventRightTopDescriptionProvider(
        dateFormatter: dateFormatter
      ),
      isTestnet: wallet.isTestnet,
      nftProvider: { [weak self] address in
        guard let self else { return nil }
        return try? self.nftService.getNFT(address: address, isTestnet: self.wallet.isTestnet)
      }
    )
    
    return eventModel
  }
  
  func mapEventCellConfiguration(_ eventModel: AccountEventModel) -> HistoryCell.Model {
    return historyEventMapper.mapEvent(
      eventModel,
      isSecureMode: appSettingsStore.getState().isSecureMode,
      nftAction: { [weak self, wallet] address in
        self?.didSelectNFT?(wallet, address)
      }, encryptedCommentAction: { [weak self, wallet] payload in
        self?.didSelectEncryptedComment?(wallet, payload)
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
