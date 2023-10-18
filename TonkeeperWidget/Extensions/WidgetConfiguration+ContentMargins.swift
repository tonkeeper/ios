//
//  WidgetConfiguration+ContentMargins.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import WidgetKit

extension WidgetConfiguration {
#if swift(>=5.9)
  func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
#else
  func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    return self
  }
#endif
}
