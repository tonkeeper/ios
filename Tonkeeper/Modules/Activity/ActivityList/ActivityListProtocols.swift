//
//  ActivityListActivityListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation
import TonSwift
import WalletCoreKeeper

enum ActivityListViewState {
  case shimmer(sections: [ActivityListSection])
  case data(sections: [ActivityListSection])
  case pagingLoading(sections: [ActivityListSection])
  case pagingError(sections: [ActivityListSection], errorTitle: String?)
}

protocol ActivityListModuleOutput: AnyObject {
//  func didSelectTransaction(in section: Int, at index: Int)
  func didSelectAction(_ action: ActivityEventAction)
  func activityListNoEvents(_ activityList: ActivityListModuleInput)
  func activityListHasEvents(_ activityList: ActivityListModuleInput)
  func didSetIsConnecting(_ isConnecting: Bool)
}

protocol ActivityListModuleCollectibleOutput: ActivityListModuleOutput {
  func didSelectCollectible(with address: Address)
}

protocol ActivityListModuleInput: AnyObject {}

protocol ActivityListPresenterInput {
  func viewDidLoad()
  func fetchNext()
  func viewModel(eventId: String) -> ActivityListCompositionTransactionCell.Model?
  func didSelectTransactionAt(indexPath: IndexPath, actionIndex: Int)
  func didSelectNFTAt(indexPath: IndexPath, actionIndex: Int)
}

protocol ActivityListViewInput: AnyObject {
  func updateSections(_ sections: [ActivityListSection])
  func showPagination(_ pagination: ActivityListSection.Pagination)
  func hidePagination()
}
