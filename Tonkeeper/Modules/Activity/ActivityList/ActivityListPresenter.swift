//
//  ActivityListActivityListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation
import WalletCore
import TonSwift

final class ActivityListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityListViewInput?
  weak var output: ActivityListModuleOutput?
  
  // MARK: - Dependencies
  
  private let activityListController: ActivityListController
  private let transactionBuilder: ActivityListTransactionBuilder
  
  private var cellsViewModels = [String: ActivityListCompositionTransactionCell.Model]()
  
  init(activityListController: ActivityListController,
       transactionBuilder: ActivityListTransactionBuilder) {
    self.activityListController = activityListController
    self.transactionBuilder = transactionBuilder
  }
}

// MARK: - ActivityListPresenterIntput

extension ActivityListPresenter: ActivityListPresenterInput {
  func viewDidLoad() {
    loadInitialEvents()
  }
  
  func didSelectTransactionAt(indexPath: IndexPath) {
    output?.didSelectTransaction(in: indexPath.section, at: indexPath.item)
  }
  
  func fetchNext() {
    Task {
      let hasMore = await activityListController.hasMore
      let isLoading = await activityListController.isLoading
      guard hasMore && !isLoading else {
        return
      }

      loadInitialEvents()
    }
  }
  
  func viewModel(eventId: String) -> ActivityListCompositionTransactionCell.Model? {
    return cellsViewModels[eventId]
  }
}

// MARK: - ActivityListModuleInput

extension ActivityListPresenter: ActivityListModuleInput {}

// MARK: - Private

private extension ActivityListPresenter {
  
  func loadInitialEvents() {
    Task {
      let viewModels = try await activityListController.loadNextEvents()
      viewModels.forEach { key, value in
        let actions = value.actions.map { action in
          return transactionBuilder.buildTransactionModel(
            type: action.eventType,
            subtitle: action.leftTopDescription,
            amount: action.amount,
            time: action.rightTopDesription,
            status: action.status,
            comment: action.comment,
            collectible: action.collectible
            )
        }
        
        let cellViewModel = ActivityListCompositionTransactionCell.Model(childTransactionModels: actions)
        cellsViewModels[key] = cellViewModel
      }
      
      let sections = await activityListController.eventsSections.map { section in
        ActivityListSection(date: section.date, title: section.title, items: section.eventsIds)
      }
      
      await MainActor.run {
        viewInput?.updateEvents(sections)
      }
    }
  }
}
