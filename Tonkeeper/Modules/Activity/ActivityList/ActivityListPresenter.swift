//
//  ActivityListActivityListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation
import WalletCoreKeeper
import TonSwift

final class ActivityListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityListViewInput?
  weak var output: ActivityListModuleOutput?
  
  // MARK: - Dependencies
  
  private let activityListController: ActivityListController
  private let transactionBuilder: ActivityListTransactionBuilder
  
  private var cellsViewModels = [String: ActivityListCompositionTransactionCell.Model]()
  private var isPagingLoading = false
  
  init(activityListController: ActivityListController,
       transactionBuilder: ActivityListTransactionBuilder) {
    self.activityListController = activityListController
    self.transactionBuilder = transactionBuilder
  }
}

// MARK: - ActivityListPresenterIntput

extension ActivityListPresenter: ActivityListPresenterInput {
  func viewDidLoad() {
    Task {
      let stream = await activityListController.eventsStream()
      for try await event in stream {
          switch event {
          case .paginationFailed:
            isPagingLoading = false
            await MainActor.run {
              viewInput?.showPagination(.error(title: "Failed to load"))
            }
          case .startLoading:
            await MainActor.run {
              showShimmer()
            }
          case .startPagination:
            await MainActor.run {
              viewInput?.showPagination(.loading)
            }
          case .stopPagination:
            isPagingLoading = false
          case .updateEvents(let eventsSections):
            let sections = await mapEventsViewModels(eventsSections)
            await MainActor.run {
              if sections.isEmpty {
                output?.activityListNoEvents(self)
              } else {
                output?.activityListHasEvents(self)
              }
              viewInput?.updateSections(sections)
            }
          }
      }
    }
    Task {
      await activityListController.start()
    }
  }
  
  func fetchNext() {
    guard !isPagingLoading else { return }
    isPagingLoading = true
    Task {
      let hasMore = await activityListController.hasMore
      let isActivityControllerLoading = await activityListController.isLoading
      guard hasMore && !isActivityControllerLoading else {
        await MainActor.run {
          isPagingLoading = false
        }
        return
      }
      await activityListController.fetchNext()
    }
    guard !isPagingLoading else { return }
    isPagingLoading = true
  }
  
  func viewModel(eventId: String) -> ActivityListCompositionTransactionCell.Model? {
    return cellsViewModels[eventId]
  }
  
  func didSelectTransactionAt(indexPath: IndexPath, actionIndex: Int) {
    
  }
  
  func didSelectNFTAt(indexPath: IndexPath, actionIndex: Int) {
    Task { [activityListController] in
      guard let collectibleAddress = try? await activityListController.getCollectibleAddress(
        sectionIndex: indexPath.section,
        eventIndex: indexPath.item,
        actionIndex: actionIndex
      ) else { return }
      
      await MainActor.run { [output] in
        (output as? ActivityListModuleCollectibleOutput)?.didSelectCollectible(with: collectibleAddress)
      }
    }
  }
}

// MARK: - ActivityListModuleInput

extension ActivityListPresenter: ActivityListModuleInput {}

// MARK: - Private

private extension ActivityListPresenter {
  func mapEventsViewModels(_ viewModels: [String: ActivityEventViewModel]) async -> [ActivityListSection] {
    viewModels.forEach { key, value in
      let actions = value.actions.map { action in
        return transactionBuilder.buildTransactionModel(
          type: action.eventType,
          subtitle: action.leftTopDescription,
          amount: action.amount,
          subamount: action.subamount,
          time: action.rightTopDescription,
          status: action.status,
          comment: action.comment,
          collectible: action.collectible
        )
      }
      
      let cellViewModel = ActivityListCompositionTransactionCell.Model(childTransactionModels: actions)
      cellsViewModels[key] = cellViewModel
    }
    
    let sections = await activityListController.eventsSections.map { section in
      ActivityListSection.events(.init(date: section.date, title: section.title, items: section.eventsIds))
    }
    
    return sections
  }
  
  func showShimmer() {
    let shimmers = (0..<5).map { _ in UUID().uuidString }
    viewInput?.updateSections([.shimmer(shimmers: shimmers)])
  }
}
