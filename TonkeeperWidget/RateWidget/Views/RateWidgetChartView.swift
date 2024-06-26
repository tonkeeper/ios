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
    chartView.setChartData(chartData.data)
    if let image = chartView.getImage(transparent: true) {
      return .init(uiImage: image)
    }
    return .init(uiImage: UIImage())
  }
  
  var body: some View {
    GeometryReader { geometry in
      chartImage(size: geometry.size)
    }
  }
}
