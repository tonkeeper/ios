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
    let items = (0..<4).map { _ in UUID().uuidString }
    let section = ActivityListSection(date: Date(), title: nil, items: items)
    viewInput?.showShimmer()
    viewInput?.updateSections([section])
    Task {
      do {
        let sections = try await loadNextEvents()
        await MainActor.run {
          if sections.isEmpty {
            output?.activityListNoEvents(self)
          }
          viewInput?.hideShimmer()
          viewInput?.updateSections(sections)
        }
      } catch {
        await MainActor.run {
          viewInput?.hideShimmer()
          viewInput?.updateSections([])
          output?.activityListNoEvents(self)
        }
      }
    }
  }
  
  func didSelectTransactionAt(indexPath: IndexPath) {
    output?.didSelectTransaction(in: indexPath.section, at: indexPath.item)
  }
  
  func reload() {
    Task {
      do {
        await activityListController.reset()
        let sections = try await loadNextEvents()
        await MainActor.run {
          if sections.isEmpty {
            output?.activityListNoEvents(self)
          }
          viewInput?.hideRefreshControl()
          viewInput?.updateSections(sections)
        }
      } catch {
        await MainActor.run {
          viewInput?.hideRefreshControl()
        }
      }
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
      
      await MainActor.run {
        viewInput?.showPagingLoader()
      }
      
      do {
        let sections = try await loadNextEvents()
        let hasMore = await activityListController.hasMore
        await MainActor.run {
          if !hasMore { viewInput?.hidePagingLoader() }
          isPagingLoading = false
          viewInput?.updateSections(sections)
        }
      } catch {
        await MainActor.run {
          isPagingLoading = false
          viewInput?.showPagingError(title: "Failed to load")
        }
      }
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
  func loadNextEvents() async throws -> [ActivityListSection] {
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
    
    return sections
  }
}
