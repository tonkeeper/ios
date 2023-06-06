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
}

// MARK: - ActivityRootPresenterIntput

extension ActivityRootPresenter: ActivityRootPresenterInput {
  func viewDidLoad() {}
}

// MARK: - ActivityRootModuleInput

extension ActivityRootPresenter: ActivityRootModuleInput {}

// MARK: - Private

private extension ActivityRootPresenter {}
