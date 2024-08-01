import UIKit
import TKUIKit
import TKLocalize
import KeeperCore

protocol HistoryV2ListModuleOutput: AnyObject {
  var didUpdate: ((_ hasEvents: Bool) -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
}
protocol HistoryV2ListModuleInput: AnyObject {}
protocol HistoryV2ListViewModel: AnyObject {
  var didUpdateSnapshot: ((HistoryV2ListViewController.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func getEventCellModel(identifier: String) -> HistoryCell.Configuration?
  func getPaginationCellModel() -> HistoryV2ListPaginationCell.Model
  func loadNextPage()
}

final class HistoryV2ListViewModelImplementation: HistoryV2ListViewModel, HistoryV2ListModuleOutput, HistoryV2ListModuleInput {
  
  struct HistoryListSection {
    let date: Date
    let title: String?
    let events: [AccountEventModel]
  }
  
  var didUpdate: ((Bool) -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  
  var didUpdateSnapshot: ((HistoryV2ListViewController.Snapshot) -> Void)?
  
  private let serialActor = SerialActor<Void>()
  private var relativeDate = Date()
  private var events = [AccountEvent]()
  private var snapshot = HistoryV2ListViewController.Snapshot()
  private var sections = [HistoryListSection]()
  private var sectionsOrderMap = [Date: Int]()
  private var eventCellModels = [String: HistoryCell.Configuration]()
  private var paginationCellModel = HistoryV2ListPaginationCell.Model(state: .none)
  
  private let wallet: Wallet
  private let paginationLoader: HistoryPaginationLoader
  private let accountEventMapper: AccountEventMapper
  private let dateFormatter: DateFormatter
  private let historyEventMapper: HistoryEventMapper
  
  init(wallet: Wallet,
       paginationLoader: HistoryPaginationLoader,
       accountEventMapper: AccountEventMapper,
       dateFormatter: DateFormatter,
       historyEventMapper: HistoryEventMapper) {
    self.wallet = wallet
    self.paginationLoader = paginationLoader
    self.accountEventMapper = accountEventMapper
    self.dateFormatter = dateFormatter
    self.historyEventMapper = historyEventMapper
  }
  
  func viewDidLoad() {
    setupLoader()
  }
  
  func getEventCellModel(identifier: String) -> HistoryCell.Configuration? {
    return eventCellModels[identifier]
  }
  
  func getPaginationCellModel() -> HistoryV2ListPaginationCell.Model {
    return paginationCellModel
  }
  
  func loadNextPage() {
    paginationLoader.loadNext()
  }
}

private extension HistoryV2ListViewModelImplementation {

  func setupLoader() {
    Task {
      let stream = await paginationLoader.createStream()
      for await event in stream {
        await self.serialActor.addTask {
          self.handleLoaderEvent(event)
        }
      }
    }
    paginationLoader.reload()
  }
  
  func handleLoaderEvent(_ event: HistoryPaginationLoader.Event) {
    switch event {
    case .loading:
      didUpdate?(true)
      handleLoading()
    case .loadingFailed:
      didUpdate?(false)
    case .loaded(let accountEvents, let hasMore):
      guard !accountEvents.events.isEmpty else {
        didUpdate?(false)
        return
      }
      handleLoaded(accountEvents, hasMore: hasMore)
    case .loadedPage(let accountEvents, let hasMore):
      handleLoadedPage(accountEvents, hasMore: hasMore)
    case .pageLoading:
      handlePageLoading()
    case .pageLoadingFailed:
      handlePageLoadingFailed()
    }
  }
  
  func handleLoading() {
    relativeDate = Date()
    events = []
    snapshot.deleteAllItems()
    snapshot.appendSections([.shimmer])
    snapshot.appendItems([.shimmer], toSection: .shimmer)
    DispatchQueue.main.async { [snapshot] in
      self.didUpdateSnapshot?(snapshot)
    }
  }
  
  func handleLoaded(_ accountEvents: AccountEvents, hasMore: Bool) {
    if snapshot.indexOfSection(.shimmer) != nil {
      snapshot.deleteSections([.shimmer])
    }
    events += accountEvents.events
    handleAccountEvents(accountEvents, hasMore: hasMore)
  }
  
  func handleLoadedPage(_ accountEvents: AccountEvents, hasMore: Bool) {
    if snapshot.indexOfSection(.shimmer) != nil {
      snapshot.deleteSections([.shimmer])
    }
    events += accountEvents.events
    handleAccountEvents(accountEvents, hasMore: hasMore)
  }
  
  func handlePageLoading() {
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems([.pagination])
    } else {
      snapshot.reloadItems([.pagination])
    }
    DispatchQueue.main.async { [snapshot] in
      self.paginationCellModel = HistoryV2ListPaginationCell.Model(state: .loading)
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
      self.paginationCellModel = HistoryV2ListPaginationCell.Model(state: .error(title: "Failed", retryButtonAction: {
        
      }))
      self.didUpdateSnapshot?(self.snapshot)
    }
  }
  
  func handleAccountEvents(_ accountsEvents: AccountEvents, hasMore: Bool) {
    snapshot.deleteSections([.pagination])
    
    let calendar = Calendar.current
    var models = [String: HistoryCell.Configuration]()
    for event in accountsEvents.events {
      let eventDate = Date(timeIntervalSince1970: event.timestamp)
      let eventSectionDateComponents: DateComponents
      let eventDateFormat: String

      if calendar.isDateInToday(eventDate)
          || calendar.isDateInYesterday(eventDate)
          || calendar.isDate(eventDate, equalTo: relativeDate, toGranularity: .month) {
        eventSectionDateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        eventDateFormat = "HH:mm"
      } else if calendar.isDate(eventDate, equalTo: relativeDate, toGranularity: .year) {
        eventSectionDateComponents = calendar.dateComponents([.year, .month], from: eventDate)
        eventDateFormat = "dd MMM, HH:mm"
      } else {
        eventSectionDateComponents = calendar.dateComponents([.year, .month], from: eventDate)
        eventDateFormat = "dd MMM yyyy, HH:mm"
      }
      dateFormatter.dateFormat = eventDateFormat
      
      guard let sectionDate = calendar.date(from: eventSectionDateComponents) else { continue }
      
      let eventModel = accountEventMapper.mapEvent(
        event,
        eventDate: eventDate,
        nftsCollection: NFTsCollection(nfts: [:]),
        accountEventRightTopDescriptionProvider: HistoryAccountEventRightTopDescriptionProvider(
          dateFormatter: dateFormatter
        ),
        isTestnet: wallet.isTestnet
      )
      
      let eventCellModel = historyEventMapper.mapEvent(
        eventModel,
        nftAction: { _ in
          
        },
        tapAction: { [weak self] accountEventDetailsEvent in
          self?.didSelectEvent?(accountEventDetailsEvent)
        }
      )
      models[eventModel.eventId] = eventCellModel
      
      if let sectionIndex = sectionsOrderMap[sectionDate],
         sections.count > sectionIndex {
        let section = sections[sectionIndex]
        let events = section.events + CollectionOfOne(eventModel)
          .sorted(by: { $0.date > $1.date })
        let updatedSection = HistoryListSection(
          date: section.date,
          title: section.title,
          events: events
        )
        
        sections.remove(at: sectionIndex)
        sections.insert(updatedSection, at: sectionIndex)
        
        let snapshotSection: HistoryV2ListSection = .events(
          HistoryV2ListEventsSection(
            date: section.date,
            title: section.title
          )
        ) 
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: snapshotSection))
        snapshot.appendItems(events.map { .event(identifier: $0.eventId) }, toSection: snapshotSection)
      } else {
        let section = HistoryListSection(
          date: sectionDate,
          title: mapEventsSectionDate(sectionDate),
          events: [eventModel]
        )
        
        sections = sections + CollectionOfOne(section)
          .sorted(by: { $0.date > $1.date })
        sectionsOrderMap = Dictionary(uniqueKeysWithValues: sections.enumerated().map {
          ($0.element.date, $0.offset) }
        )
        
        let snapshotSection: HistoryV2ListSection = .events(
          HistoryV2ListEventsSection(
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
    DispatchQueue.main.async { [snapshot, models] in
      self.eventCellModels.merge(models) { $1 }
      self.didUpdateSnapshot?(snapshot)
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
