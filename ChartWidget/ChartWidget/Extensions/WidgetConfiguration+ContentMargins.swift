//
//  WidgetConfiguration+ContentMargins.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI
import WidgetKit

extension WidgetConfiguration {
  func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}
