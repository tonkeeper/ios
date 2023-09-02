//
//  ToastConfiguration.swift
//  Tonkeeper
//
//  Created by Grigory on 31.7.23..
//

import Foundation

extension ToastController.Configuration {
  static var copied: ToastController.Configuration {
    .init(title: "Copied.")
  }
  
  static var loading: ToastController.Configuration {
    .init(title: "Loading", shape: .oval, isActivity: true, dismissRule: .none)
  }
  
  static var failed: ToastController.Configuration {
    .init(title: "Failed.")
  }
}
