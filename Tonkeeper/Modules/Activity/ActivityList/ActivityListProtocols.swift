//
//  ActivityListActivityListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

protocol ActivityListModuleOutput: AnyObject {}

protocol ActivityListModuleInput: AnyObject {}

protocol ActivityListPresenterInput {
  func viewDidLoad()
}

protocol ActivityListViewInput: AnyObject {
  func updateSections(_ sections: [ActivityListSection])
}
