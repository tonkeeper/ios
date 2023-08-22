//
//  CollectibleDetailsCollectibleDetailsProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import Foundation

protocol CollectibleDetailsModuleOutput: AnyObject {
  func collectibleDetailsDidFinish(_ collectibleDetails: CollectibleDetailsModuleInput)
}

protocol CollectibleDetailsModuleInput: AnyObject {}

protocol CollectibleDetailsPresenterInput {
  func viewDidLoad()
  func didTapSwipeButton()
}

protocol CollectibleDetailsViewInput: AnyObject {}
