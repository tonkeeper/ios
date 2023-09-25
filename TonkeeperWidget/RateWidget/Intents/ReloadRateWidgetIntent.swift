//
//  ReloadRateWidgetIntent.swift.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import AppIntents
import Intents
@available(iOSApplicationExtension 16, *)
struct ReloadRateWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "Reload rate"
  
  init() {}
  
  func perform() async throws -> some IntentResult {
    return .result()
  }
}
