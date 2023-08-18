//
//  InAppBrowserMainInAppBrowserMainProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import Foundation

protocol InAppBrowserMainModuleOutput: AnyObject {}

protocol InAppBrowserMainModuleInput: AnyObject {}

protocol InAppBrowserMainPresenterInput {
  func viewDidLoad()
}

protocol InAppBrowserMainViewInput: AnyObject {}