//
//  ActivityListActivityListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

protocol ActivityListModuleOutput: AnyObject {
  func didSelectTransaction(in section: Int, at index: Int)
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
  func updateEvents(_ sections: [ActivityListSection])
  func stopLoading()
}
