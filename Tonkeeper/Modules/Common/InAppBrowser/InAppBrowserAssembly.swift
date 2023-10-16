//
//  InAppBrowserAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import Foundation

final class InAppBrowserAssembly {
  
  func coordinator(router: NavigationRouter,
                   url: URL) -> InAppBrowserCoordinator {
    InAppBrowserCoordinator(router: router, url: url)
  }
}
