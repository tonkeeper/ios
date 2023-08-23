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

protocol CollectibleDetailsViewInput: AnyObject {
  func updateTitle(_ title: String)
  func updateCollectibleSection(model: CollectibleDetailsCollectibleView.Model)
  func updateContentSection(model: CollectibleDetailsCollectionDescriptionView.Model)
  func updateDetailsSection(model: CollectibleDetailsDetailsView.Model)
  func updatePropertiesSection(model: CollectibleDetailsPropertiesСarouselView.Model)
}
