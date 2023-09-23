//
//  ChartWidgetChartView.swift
//  ChartWidgetExtension
//
//  Created by Grigory on 23.9.23..
//

import SwiftUI
import TKChart

struct ChartWidgetChartView: View {
  let chartData: TKLineChartView.Data
  
  func chartImage(size: CGSize) -> SwiftUI.Image {
    let chartView = TKLineChartView()
    chartView.frame.size = size
    chartView.layoutIfNeeded()
    chartView.setData(chartData)
    if let image = chartView.getChartImage(transparent: false) {
      return .init(uiImage: image)
    }
    return .init(uiImage: .Images.Mock.mercuryoLogo!)
  }
  
  var body: some View {
    GeometryReader { geometry in
      chartImage(size: .init(width: geometry.size.width + 20, height: geometry.size.height))
        .offset(x: -10)
    }
  }
}
