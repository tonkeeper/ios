//
//  URLOpener.swift
//  Signer
//
//  Created by Grigory Serebryanyy on 03.05.2024.
//

import UIKit

public protocol URLOpener {
  func open(url: URL)
}

extension UIApplication: URLOpener {
  public func open(url: URL) {
    open(url, options: [:], completionHandler: nil)
  }
}
