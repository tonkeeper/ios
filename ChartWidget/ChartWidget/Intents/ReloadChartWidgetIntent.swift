//
//  ReloadChartWidgetIntent.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import Foundation

import AppIntents
import Intents
@available(iOSApplicationExtension 16, *)
struct ReloadChartWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "Reload chart widget"
  
  init() {}
  
  func perform() async throws -> some IntentResult {
    return .result()
  }
}

