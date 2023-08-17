//
//  TonChartTonChartView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit
import DGCharts

final class TonChartView: UIView {
  
  let headerView = TonChartHeaderView()
  let chartView = LineChartView()
  let buttonsView = TonChartButtonsView()

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
    CGSize(width: UIView.noIntrinsicMetric, height: 300)
  }
}

// MARK: - Private

private extension TonChartView {
  func setup() {
    addSubview(headerView)
    addSubview(chartView)
    addSubview(buttonsView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    headerView.translatesAutoresizingMaskIntoConstraints = false
    chartView.translatesAutoresizingMaskIntoConstraints = false
    buttonsView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: topAnchor),
      headerView.leftAnchor.constraint(equalTo: leftAnchor),
      headerView.rightAnchor.constraint(equalTo: rightAnchor),
      
      chartView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      chartView.leftAnchor.constraint(equalTo: leftAnchor, constant: .chartSideSpacing),
      chartView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.chartSideSpacing),

      buttonsView.topAnchor.constraint(equalTo: chartView.bottomAnchor),
      buttonsView.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsView.rightAnchor.constraint(equalTo: rightAnchor),
      buttonsView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let chartSideSpacing: CGFloat = -10
}
