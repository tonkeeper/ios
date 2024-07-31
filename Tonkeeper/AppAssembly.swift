//
//  AppAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKCore

final class AppAssembly {
  let coreAssembly = CoreAssembly(
    analyticsProvider: AnalyticsProvider(
      analyticsServices: AptabaseService()
    )
  )
}
