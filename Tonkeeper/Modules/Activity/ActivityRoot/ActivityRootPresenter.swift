//
//  ActivityRootActivityRootPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

final class ActivityRootPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityRootViewInput?
  weak var output: ActivityRootModuleOutput?
  
  weak var emptyInput: ActivityEmptyModuleInput?
  weak var listInput: ActivityListModuleInput?
}

// MARK: - ActivityRootPresenterIntput

extension ActivityRootPresenter: ActivityRootPresenterInput {
  func viewDidLoad() {}
}

// MARK: - ActivityRootModuleInput

extension ActivityRootPresenter: ActivityRootModuleInput {}

// MARK: - ActivityEmptyModuleOutput

extension ActivityRootPresenter: ActivityEmptyModuleOutput {
  func didTapReceiveButton() {
    output?.didTapReceiveButton()
  }
}

// MARK: - ActivityListModuleOutput

extension ActivityRootPresenter: ActivityListModuleOutput {}

// MARK: - Private

private extension ActivityRootPresenter {}
