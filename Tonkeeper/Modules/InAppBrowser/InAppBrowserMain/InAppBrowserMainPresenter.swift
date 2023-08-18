//
//  InAppBrowserMainInAppBrowserMainPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import Foundation

final class InAppBrowserMainPresenter {
  
  // MARK: - Module
  
  weak var viewInput: InAppBrowserMainViewInput?
  weak var output: InAppBrowserMainModuleOutput?
}

// MARK: - InAppBrowserMainPresenterIntput

extension InAppBrowserMainPresenter: InAppBrowserMainPresenterInput {
  func viewDidLoad() {}
}

// MARK: - InAppBrowserMainModuleInput

extension InAppBrowserMainPresenter: InAppBrowserMainModuleInput {}

// MARK: - Private

private extension InAppBrowserMainPresenter {}
