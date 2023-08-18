//
//  InAppBrowserMainInAppBrowserMainProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import Foundation

protocol InAppBrowserMainModuleOutput: AnyObject {
  func inAppBrowserMainDidFinish(_ inAppBrowserMain: InAppBrowserMainModuleInput)
}

protocol InAppBrowserMainModuleInput: AnyObject {}

protocol InAppBrowserMainPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
  func didTapMenuButton()
  func didPullToRefresh()
  func didChangeURL(_ url: URL)
}

protocol InAppBrowserMainViewInput: AnyObject {
  func loadURLRequest(_ urlRequest: URLRequest)
}
