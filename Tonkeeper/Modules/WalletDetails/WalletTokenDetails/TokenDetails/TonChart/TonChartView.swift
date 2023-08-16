//
//  TonChartTonChartView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit
import DGCharts

final class TonChartView: UIView {
  
  let chartView = LineChartView()

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 418)
  }
}

// MARK: - Private

private extension TonChartView {
  func setup() {
    addSubview(chartView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    chartView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      chartView.topAnchor.constraint(equalTo: topAnchor),
      chartView.leftAnchor.constraint(equalTo: leftAnchor),
      chartView.rightAnchor.constraint(equalTo: rightAnchor),
      chartView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}
