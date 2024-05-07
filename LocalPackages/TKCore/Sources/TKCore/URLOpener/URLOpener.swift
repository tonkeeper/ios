//
//  URLOpener.swift
//
//
//  Created by Grigory on 29.9.23..
//

import UIKit

public protocol URLOpener {
  func open(url: URL)
  func canOpen(url: URL) -> Bool
}

extension UIApplication: URLOpener {
  public func open(url: URL) {
    open(url, options: [:], completionHandler: nil)
  }
  
  public func canOpen(url: URL) -> Bool {
    canOpenURL(url)
  }
}
