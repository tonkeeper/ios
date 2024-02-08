import Foundation
import TKUIKit
import KeeperCore

protocol HistoryListModuleOutput: AnyObject {
  
}

protocol HistoryListModuleInput: AnyObject {
  
}

protocol HistoryListViewModel: AnyObject {
  var didUpdateHistory: (([HistoryListSection]) -> Void)? { get set }
  
  func viewDidLoad()
  func loadNext()
}

final class HistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput, HistoryListModuleInput {
  
  // MARK: - HistoryListModuleOutput
  
  // MARK: - HistoryListModuleInput
  
  // MARK: - HistoryListViewModel
  
  var didUpdateHistory: (([HistoryListSection]) -> Void)?
  
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
    case .didLoadEvents(let sections):
      handleLoadedEvents(sections)
    case .didReset:
      cachedEventsModels = [:]
    }
  }
  
  func handleLoadedEvents(_ loadedSections: [KeeperCore.HistoryListSection]) {
    let sectionsModels = loadedSections.map { section in
      let eventsModels = section.events.map { event in
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
    }
  }
  
  func mapEvent(_ event: HistoryListEvent) -> HistoryEventCell.Model {
    if let eventModel = cachedEventsModels[event.eventId] {
      return eventModel
    } else {
      let eventModel = historyEventMapper.mapEvent(event)
      cachedEventsModels[event.eventId] = eventModel
      return eventModel
    }
  }
}
