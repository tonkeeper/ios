//
//  RateWidgetChartView.swift
//  TonkeeperWidgetExtension
//
//  Created by Grigory on 25.9.23..
//

import SwiftUI
import TKChart

struct RateWidgetChartView: View {
  let chartData: RateWidgetEntry.ChartData
  
  func chartImage(size: CGSize) -> SwiftUI.Image {
    let chartView = TKLineChartView()
    chartView.frame.size = size
    chartView.layoutIfNeeded()
    chartView.setData(chartData.data)
    if let image = chartView.getChartImage(transparent: false) {
      return .init(uiImage: image)
    }
    return .init(uiImage: .Images.Mock.mercuryoLogo!)
  }
  
  var body: some View {
    GeometryReader { geometry in
      chartImage(size: geometry.size)
    }
  }
}
