//
//  ActivityListActivityListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

enum ActivityListViewState {
  case shimmer(sections: [ActivityListSection])
  case data(sections: [ActivityListSection])
  case pagingLoading(sections: [ActivityListSection])
  case pagingError(sections: [ActivityListSection], errorTitle: String?)
}

protocol ActivityListModuleOutput: AnyObject {
  func didSelectTransaction(in section: Int, at index: Int)
  func activityListNoEvents(_ activityList: ActivityListModuleInput)
}

protocol ActivityListModuleInput: AnyObject {}

protocol ActivityListPresenterInput {
  func viewDidLoad()
  func didSelectTransactionAt(indexPath: IndexPath)
  func reload()
  func fetchNext()
  func viewModel(eventId: String) -> ActivityListCompositionTransactionCell.Model?
}

protocol ActivityListViewInput: AnyObject {
//  func didUpdateState(state: ActivityListViewState)
//  func updateEvents(_ sections: [ActivityListSection])
//  func showLoadingIndicator()
//  func hideLoadingIndicator()
  func hideRefreshControl()
//  func showShimmer()
//  func hideShimmer()
//  func showPagingError(title: String?)
  func updateSections(_ sections: [ActivityListSection])
  
  func showPagingLoader()
  
  func hidePagingLoader()
  
  func showPagingError(title: String?)
  
  func showShimmer()
  
  func hideShimmer()
}
