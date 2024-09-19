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
protocol HistoryListViewModel: AnyObject {
  var didUpdateSnapshot: ((HistoryListViewController.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func getEventCellModel(identifier: String) -> HistoryCell.Model?
  func getPaginationCellModel() -> HistoryListPaginationCell.Model
  func loadNextPage()
}

final class HistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput {
  
  struct EventsSection {
    let date: Date
    let title: String?
    let events: [AccountEvent]
  }
  
  var didUpdateState: ((_ hasEvents: Bool) -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)?
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload) -> Void)?
  
  var didUpdateSnapshot: ((HistoryListViewController.Snapshot) -> Void)?
  
  private let serialActor = SerialActor<Void>()
  private var relativeDate = Date()
  private var events = [AccountEvent]()
  private var eventsOrderMap = [String: Int]()
  private var snapshot = HistoryListViewController.Snapshot()
  private var sections = [EventsSection]()
  private var sectionsOrderMap = [Date: Int]()
  private var eventCellModels = [String: HistoryCell.Model]()
  private var paginationCellModel = HistoryListPaginationCell.Model(state: .none)
  private var loadNFTsTasks = [Address: Task<NFT, Swift.Error>]()
  
  private let wallet: Wallet
  private let paginationLoader: HistoryPaginationLoader
  private let cacheProvider: HistoryListCacheProvider
  private let nftService: NFTService
  private let accountEventMapper: AccountEventMapper
  private let dateFormatter: DateFormatter
  private let historyEventMapper: HistoryEventMapper
  
  init(wallet: Wallet,
       paginationLoader: HistoryPaginationLoader,
       cacheProvider: HistoryListCacheProvider,
       nftService: NFTService,
       accountEventMapper: AccountEventMapper,
       dateFormatter: DateFormatter,
       historyEventMapper: HistoryEventMapper) {
    self.wallet = wallet
    self.paginationLoader = paginationLoader
    self.cacheProvider = cacheProvider
    self.nftService = nftService
    self.accountEventMapper = accountEventMapper
    self.dateFormatter = dateFormatter
    self.historyEventMapper = historyEventMapper
  }
  
  func viewDidLoad() {
    setInitialState()
    setupLoader()
  }
  
  func getEventCellModel(identifier: String) -> HistoryCell.Model? {
    return eventCellModels[identifier]
  }
  
  func getPaginationCellModel() -> HistoryListPaginationCell.Model {
    return paginationCellModel
  }
  
  func loadNextPage() {
    paginationLoader.loadNext()
  }
}

private extension HistoryListViewModelImplementation {

  func setInitialState() {
    do {
      let cached = try cacheProvider.getCache(wallet: wallet)
      if cached.isEmpty {
        didUpdateState?(false)
      } else {
        cached.forEach { event in
          self.events.append(event)
          eventsOrderMap[event.eventId] = self.events.count - 1
        }
        let (snapshot, cellModels) = handleAccountEvents(cached, hasMore: false)
        self.eventCellModels.merge(cellModels) { $1 }
        self.snapshot = snapshot
        didUpdateSnapshot?(snapshot)
      }
    } catch {
      snapshot.appendSections([.shimmer])
      snapshot.appendItems([.shimmer], toSection: .shimmer)
      didUpdateSnapshot?(snapshot)
    }
  }
  
  func setupLoader() {
    paginationLoader.didGetEvent = { event in
      Task {
        await self.serialActor.addTask {
          await self.handleLoaderEvent(event)
        }
      }
    }
    paginationLoader.reload()
  }
  
  func handleLoaderEvent(_ event: HistoryPaginationLoader.Event) async {
    switch event {
    case .loading:
      break
    case .loadingFailed:
      handleLoadingFailed()
    case .loaded(let accountEvents, let hasMore):
      try? cacheProvider.setCache(events: self.events, wallet: wallet)
      await handleLoaded(accountEvents, hasMore: hasMore)
    case .loadedPage(let accountEvents, let hasMore):
      await handleLoadedPage(accountEvents, hasMore: hasMore)
    case .pageLoading:
      handlePageLoading()
    case .pageLoadingFailed:
      handlePageLoadingFailed()
    }
  }
  
  func reset() {
    relativeDate = Date()
    events = []
    eventsOrderMap.removeAll()
    sections.removeAll()
    sectionsOrderMap.removeAll()
    snapshot.deleteAllItems()
  }

  func handleLoadingFailed() {
    reset()
    snapshot.deleteAllItems()
    DispatchQueue.main.async { [snapshot] in
      self.didUpdateState?(false)
      self.didUpdateSnapshot?(snapshot)
    }
  }

  func handleLoaded(_ accountEvents: AccountEvents, hasMore: Bool) async {
    reset()
    guard !accountEvents.events.isEmpty else {
      await MainActor.run {
        self.didUpdateState?(false)
        self.didUpdateSnapshot?(self.snapshot)
      }
      return
    }
    accountEvents.events.forEach { event in
      self.events.append(event)
      eventsOrderMap[event.eventId] = self.events.count - 1
    }
    await handleEventsWithNFTs(events: accountEvents.events)
    let (snapshot, cellModels) = handleAccountEvents(accountEvents.events, hasMore: hasMore)
    await MainActor.run {
      self.didUpdateState?(true)
      self.eventCellModels.merge(cellModels) { $1 }
      self.snapshot = snapshot
      self.didUpdateSnapshot?(snapshot)
    }
  }
  
  func handleLoadedPage(_ accountEvents: AccountEvents, hasMore: Bool) async {
    if snapshot.indexOfSection(.shimmer) != nil {
      snapshot.deleteSections([.shimmer])
    }
    accountEvents.events.forEach { event in
      self.events.append(event)
      eventsOrderMap[event.eventId] = self.events.count - 1
    }
    try? cacheProvider.setCache(events: self.events, wallet: wallet)
    await handleEventsWithNFTs(events: accountEvents.events)
    let (snapshot, cellModels) = handleAccountEvents(accountEvents.events, hasMore: hasMore)
    await MainActor.run {
      self.eventCellModels.merge(cellModels) { $1 }
      self.snapshot = snapshot
      didUpdateSnapshot?(snapshot)
    }
  }
  
  func handlePageLoading() {
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems([.pagination])
    } else {
      snapshot.reloadItems([.pagination])
    }
    DispatchQueue.main.async { [snapshot] in
      self.paginationCellModel = HistoryListPaginationCell.Model(state: .loading)
      self.didUpdateSnapshot?(snapshot)
    }
  }
  
  func handlePageLoadingFailed() {
    if #available(iOS 15.0, *) {
      self.snapshot.reconfigureItems([.pagination])
    } else {
      self.snapshot.reloadItems([.pagination])
    }
    DispatchQueue.main.async {
      self.paginationCellModel = HistoryListPaginationCell.Model(state: .error(title: TKLocales.Actions.failed, retryButtonAction: { [weak self] in
        self?.loadNextPage()
      }))
      self.didUpdateSnapshot?(self.snapshot)
    }
  }
  
  func handleAccountEvents(_ accountsEvents: [AccountEvent], hasMore: Bool)
  -> (snapshot: HistoryListViewController.Snapshot, eventCellModels: [String: HistoryCell.Model]) {
    var snapshot = self.snapshot
    
    snapshot.deleteSections([.pagination])
    
    let calendar = Calendar.current
    var models = [String: HistoryCell.Model]()
    for event in accountsEvents {
      let eventSectionDateComponents: DateComponents
      let eventDateFormat: String

      if calendar.isDateInToday(event.date)
          || calendar.isDateInYesterday(event.date)
          || calendar.isDate(event.date, equalTo: relativeDate, toGranularity: .month) {
        eventSectionDateComponents = calendar.dateComponents([.year, .month, .day], from: event.date)
        eventDateFormat = "HH:mm"
      } else if calendar.isDate(event.date, equalTo: relativeDate, toGranularity: .year) {
        eventSectionDateComponents = calendar.dateComponents([.year, .month], from: event.date)
        eventDateFormat = "dd MMM, HH:mm"
      } else {
        eventSectionDateComponents = calendar.dateComponents([.year, .month], from: event.date)
        eventDateFormat = "dd MMM yyyy, HH:mm"
      }
      dateFormatter.dateFormat = eventDateFormat
      
      guard let sectionDate = calendar.date(from: eventSectionDateComponents) else { continue }
      
      let eventModel = mapEvent(event)
      let eventCellModel = mapEventCellModel(eventModel)
      models[eventModel.eventId] = eventCellModel
      
      if let sectionIndex = sectionsOrderMap[sectionDate],
         sections.count > sectionIndex {
        let section = sections[sectionIndex]
        let events = section.events + CollectionOfOne(event)
          .sorted(by: { $0.date > $1.date })
        let updatedSection = EventsSection(
          date: section.date,
          title: section.title,
          events: events
        )
        
        sections.remove(at: sectionIndex)
        sections.insert(updatedSection, at: sectionIndex)
        
        let snapshotSection: HistoryListSection = .events(
          HistoryListEventsSection(
            date: section.date,
            title: section.title
          )
        ) 
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: snapshotSection))
        snapshot.appendItems(events.map { .event(identifier: $0.eventId) }, toSection: snapshotSection)
      } else {
        let section = EventsSection(
          date: sectionDate,
          title: mapEventsSectionDate(sectionDate),
          events: [event]
        )
        
        sections = sections + CollectionOfOne(section)
          .sorted(by: { $0.date > $1.date })
        sectionsOrderMap = Dictionary(uniqueKeysWithValues: sections.enumerated().map {
          ($0.element.date, $0.offset) }
        )
        
        let snapshotSection: HistoryListSection = .events(
          HistoryListEventsSection(
            date: section.date,
            title: section.title
          )
        )
        
        if let sectionIndex = sectionsOrderMap[sectionDate],
           sectionIndex < snapshot.sectionIdentifiers.count {
          let previousSnapshotSection = snapshot.sectionIdentifiers[sectionIndex]
          snapshot.insertSections(
            [snapshotSection],
            beforeSection: previousSnapshotSection
          )
        } else {
          snapshot.appendSections([snapshotSection])
        }
        
        snapshot.appendItems([.event(identifier: eventModel.eventId)], toSection: snapshotSection)
      }
    }
    if hasMore {
      snapshot.appendSections([.pagination])
      snapshot.appendItems([.pagination])
    }
    
    return (snapshot, models)
  }
  
  func mapEvent(_ event: AccountEvent) -> AccountEventModel {
    let calendar = Calendar.current
    let eventDate = event.date
    let eventDateFormat: String

    if calendar.isDateInToday(eventDate)
        || calendar.isDateInYesterday(eventDate)
        || calendar.isDate(eventDate, equalTo: relativeDate, toGranularity: .month) {
      eventDateFormat = "HH:mm"
    } else if calendar.isDate(eventDate, equalTo: relativeDate, toGranularity: .year) {
      eventDateFormat = "dd MMM, HH:mm"
    } else {
      eventDateFormat = "dd MMM yyyy, HH:mm"
    }
    dateFormatter.dateFormat = eventDateFormat

    let eventModel = accountEventMapper.mapEvent(
      event,
      eventDate: eventDate,
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
  
  func handleEventsWithNFTs(events: [AccountEvent]) async {
    let actions = events.flatMap { $0.actions }
    var nftAddressesToLoad = Set<Address>()
    for action in actions {
      switch action.type {
      case .nftItemTransfer(let nftItemTransfer):
        nftAddressesToLoad.insert(nftItemTransfer.nftAddress)
      case .nftPurchase(let nftPurchase):
        try? nftService.saveNFT(nft: nftPurchase.nft, isTestnet: wallet.isTestnet)
      default: continue
      }
    }
    guard !nftAddressesToLoad.isEmpty else { return }
    _ = try? await nftService.loadNFTs(addresses: Array(nftAddressesToLoad), isTestnet: wallet.isTestnet)
  }
  
  func mapEventCellModel(_ eventModel: AccountEventModel) -> HistoryCell.Model {
    return historyEventMapper.mapEvent(
      eventModel,
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
