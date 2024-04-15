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
  var didResetList: (() -> Void)? { get set }
  var didUpdateHistory: (([HistoryListSection]) -> Void)? { get set }
  var didStartPagination: ((HistoryListSection.Pagination) -> Void)? { get set }
  var didStartLoading: (() -> Void)? { get set }
  var reloadEvent: (() -> Void)? { get set }
  
  func viewDidLoad()
  func loadNext()
}

final class HistoryListViewModelImplementation: HistoryListViewModel, HistoryListModuleOutput, HistoryListModuleInput {
  
  actor CachedModels {
    var models = [String: HistoryCell.Configuration]()
    
    func setModel(_ model: HistoryCell.Configuration, id: String) {
      models[id] = model
    }
    
    func reset() {
      models.removeAll()
    }
  }
  
  // MARK: - HistoryListModuleOutput
  
  var noEvents: (() -> Void)?
  var hasEvents: (() -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((NFT) -> Void)?
  
  // MARK: - HistoryListModuleInput
  
  // MARK: - HistoryListViewModel
  
  var didResetList: (() -> Void)?
  var didUpdateHistory: (([HistoryListSection]) -> Void)?
  var didStartPagination: ((HistoryListSection.Pagination) -> Void)?
  var didStartLoading: (() -> Void)?
  var reloadEvent: (() -> Void)?
  
  func viewDidLoad() {
    Task {
      historyListController.didGetEvent = { [weak self] event in
        self?.handleEvent(event)
      }
      await historyListController.start()
    }
  }
  
  func loadNext() {
    Task {
      await historyListController.loadNext()
    }
  }
  
  // MARK: - State
  
  private var cachedModels = CachedModels()
    
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
  func handleEvent(_ event: PaginationEvent<KeeperCore.HistoryListSection>) {
    Task {
      switch event {
      case .cached(let updatedSections):
        await cachedModels.reset()
        await MainActor.run {
          didResetList?()
        }
        await handleUpdatedSections(updatedSections)
      case .loading:
        await MainActor.run {
          didStartLoading?()
        }
      case .empty:
        await MainActor.run {
          noEvents?()
        }
      case .loaded(let updatedSections):
        await cachedModels.reset()
        await MainActor.run {
          didResetList?()
        }
        await handleUpdatedSections(updatedSections)
      case .nextPage(let updatedSections):
        await handleUpdatedSections(updatedSections)
      case .pageLoading:
        await MainActor.run {
          didStartPagination?(.loading)
        }
      case .pageLoadingFailed:
        await MainActor.run {
          didStartPagination?(.error(title: "Failed to load"))
        }
      }
    }
  }
  
  func handleUpdatedSections(_ updatedSections: [KeeperCore.HistoryListSection]) async {
    var sections = [HistoryListSection]()
    for updatedSection in updatedSections {
      var eventModels = [HistoryCell.Configuration]()
      for event in updatedSection.events {
        await eventModels.append(mapEvent(event))
      }
      let section = HistoryListEventsSection(
        date: updatedSection.date,
        title: updatedSection.title,
        events: eventModels
      )
      sections.append(HistoryListSection.events(section))
    }
    let resultSections = sections
    await MainActor.run {
      hasEvents?()
      didUpdateHistory?(resultSections)
    }
  }
  
  func mapEvent(_ event: HistoryEvent) async -> HistoryCell.Configuration {
    if let cachedModel = await cachedModels.models[event.eventId] {
      return cachedModel
    } else {
      let model = historyEventMapper.mapEvent(event) { [weak self] nft in
        self?.didSelectNft(nft)
      } tapAction: { [weak self] accountEventDetailsEvent in
        self?.didSelectEvent?(accountEventDetailsEvent)
      }
      await cachedModels.setModel(model, id: event.eventId)
      return model
    }
  }
  
  func didSelectNft(_ nft: NFT) {
    didSelectNFT?(nft)
  }
}
