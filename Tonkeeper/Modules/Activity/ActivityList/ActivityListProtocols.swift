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
}

protocol ActivityListViewInput: AnyObject {
  func updateSections(_ sections: [ActivityListSection])
}
