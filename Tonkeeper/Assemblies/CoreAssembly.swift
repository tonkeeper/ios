//
//  CoreAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

struct CoreAssembly {
  var appSetting: AppSettings {
    AppSettings()
  }
  
  var documentsURL: URL {
    let documentsDirectory: URL
    if #available(iOS 16.0, *) {
      documentsDirectory = URL.documentsDirectory
    } else {
      documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    return documentsDirectory
  }
  
  var fileManager: FileManager {
    .default
  }
  
  func urlOpener() -> URLOpener {
    URLOpener(systemOpener: systemOpener, inAppOpener: inAppOpener())
  }
}

private extension CoreAssembly {
  var systemOpener: URLSystemOpener {
    UIApplication.shared
  }
  
  func inAppOpener() -> URLInAppOpener {
    DefaultURLInAppOpener()
  }
}
