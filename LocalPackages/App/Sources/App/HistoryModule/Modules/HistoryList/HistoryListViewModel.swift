import Foundation
import TKUIKit
import KeeperCore

protocol HistoryListModuleOutput: AnyObject {
  var noEvents: (() -> Void)? { get set }
  var hasEvents: (() -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
  var didSelectNFT: ((NFT) -> Void)? { get set }
}

protocol HistoryListModuleInput: AnyObject {
  
}

protocol HistoryListViewModel: AnyObject {
  var didUpdateHistory: (([HistoryListSection]) -> Void)? { get set }
  var didStartPagination: ((HistoryListSection.Pagination) -> Void)? { get set }
  var didStartLoading: (() -> Void)? { get set }
  
  func viewDidLoad()
  func loadNext()
}

final class HistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput, HistoryListModuleInput {
  
  // MARK: - HistoryListModuleOutput
  
  var noEvents: (() -> Void)?
  var hasEvents: (() -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((NFT) -> Void)?
  
  // MARK: - HistoryListModuleInput
  
  // MARK: - HistoryListViewModel
  
  var didUpdateHistory: (([HistoryListSection]) -> Void)?
  var didStartPagination: ((HistoryListSection.Pagination) -> Void)?
  var didStartLoading: (() -> Void)?
  
  func viewDidLoad() {
    historyListController.didSendEvent = { [weak self] event in
      self?.handleEvent(event)
    }
    historyListController.start()
  }
  
  func loadNext() {
    historyListController.loadNext()
  }
  
  // MARK: - State
  
  private var cachedEventsModels = [String: HistoryEventCell.Model]()
  
  // MARK: - Dependencies
  
  private let historyListController: HistoryListController
  private let historyEventMapper: HistoryEventMapper
  
  // MARK: - Init
  
  init(historyListController: HistoryListController,
       historyEventMapper: HistoryEventMapper) {
    self.historyListController = historyListController
    self.historyEventMapper = historyEventMapper
  }
}

private extension HistoryListViewModelImplementation {
  func handleEvent(_ event: HistoryListController.Event) {
    switch event {
    case .reset:
      cachedEventsModels = [:]
    case .loadingStart:
      Task { @MainActor in
        didStartLoading?()
      }
    case .noEvents:
      Task { @MainActor in
        noEvents?()
      }
    case .events(let sections):
      handleLoadedEvents(sections)
    case .paginationStart:
      Task { @MainActor in
        didStartPagination?(.loading)
      }
    case .paginationFailed:
      Task { @MainActor in
        didStartPagination?(.error(title: "Failed to load"))
      }
    }
  }
  
  func handleLoadedEvents(_ loadedSections: [KeeperCore.HistoryListSection]) {
    let sectionsModels = loadedSections.map { section in
      let eventsModels = section.events.enumerated().map { index, event in
        mapEvent(event)
      }
      let section = HistoryListEventsSection(
        date: section.date,
        title: section.title,
        events: eventsModels
      )
      return HistoryListSection.events(section)
    }
    Task { @MainActor in
      didUpdateHistory?(sectionsModels)
      hasEvents?()
    }
  }
  
  func mapEvent(_ event: HistoryListEvent) -> HistoryEventCell.Model {
    if let eventModel = cachedEventsModels[event.eventId] {
      return eventModel
    } else {
      let eventModel = historyEventMapper.mapEvent(
        event,
        nftAction: { [weak self] nft in
          self?.didSelectNFT?(nft)
        },
        tapAction: { [weak self] accountEventDetailsEvent in
          self?.didSelectEvent?(accountEventDetailsEvent)
        }
      )
      cachedEventsModels[event.eventId] = eventModel
      return eventModel
    }
  }
}
