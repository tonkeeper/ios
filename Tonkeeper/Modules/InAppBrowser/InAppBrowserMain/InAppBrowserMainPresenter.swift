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
  
  // MARK: - Dependencies
  
  private var url: URL
  
  init(url: URL) {
    self.url = url
  }
}

// MARK: - InAppBrowserMainPresenterIntput

extension InAppBrowserMainPresenter: InAppBrowserMainPresenterInput {
  func viewDidLoad() {
    viewInput?.loadURLRequest(URLRequest(url: url))
  }
  
  func didTapMenuButton() {
    
  }
  
  func didTapCloseButton() {
    output?.inAppBrowserMainDidFinish(self)
  }
  
  func didChangeURL(_ url: URL) {
    self.url = url
  }
  
  func didPullToRefresh() {
    viewInput?.loadURLRequest(URLRequest(url: url))
  }
}

// MARK: - InAppBrowserMainModuleInput

extension InAppBrowserMainPresenter: InAppBrowserMainModuleInput {}

// MARK: - Private

private extension InAppBrowserMainPresenter {}
