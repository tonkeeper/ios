//
//  URLOpener.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

enum TKURL {
  case inApp(URL)
  case system(URL)
}

protocol URLSystemOpener {
  func open(url: URL)
}

protocol URLInAppOpener {
  func open(url: URL)
}

struct URLOpener {
  let systemOpener: URLSystemOpener
  let inAppOpener: URLInAppOpener
  
  func open(url: TKURL) {
    switch url {
    case .inApp(let url):
      inAppOpener.open(url: url)
    case .system(let url):
      systemOpener.open(url: url)
    }
  }
}

extension UIApplication: URLSystemOpener {
  func open(url: URL) {
    self.open(url)
  }
}

struct DefaultURLInAppOpener: URLInAppOpener {
  func open(url: URL) {
    // TBD: open app browser
  }
}
