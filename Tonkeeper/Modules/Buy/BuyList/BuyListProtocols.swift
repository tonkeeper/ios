//
//  BuyListBuyListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation

protocol BuyListModuleOutput: AnyObject {}

protocol BuyListModuleInput: AnyObject {}

protocol BuyListPresenterInput {
  func viewDidLoad()
  func didSelectServiceAt(indexPath: IndexPath)
}

protocol BuyListViewInput: AnyObject {
  func updateSections(_ sections: [BuyListSection])
}
