//
//  CollectibleDetailsCollectibleDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import Foundation

final class CollectibleDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: CollectibleDetailsViewInput?
  weak var output: CollectibleDetailsModuleOutput?
}

// MARK: - CollectibleDetailsPresenterIntput

extension CollectibleDetailsPresenter: CollectibleDetailsPresenterInput {
  func viewDidLoad() {}
  func didTapSwipeButton() {
    output?.collectibleDetailsDidFinish(self)
  }
}

// MARK: - CollectibleDetailsModuleInput

extension CollectibleDetailsPresenter: CollectibleDetailsModuleInput {}

// MARK: - Private

private extension CollectibleDetailsPresenter {}
