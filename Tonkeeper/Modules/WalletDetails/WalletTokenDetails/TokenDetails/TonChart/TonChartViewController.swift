//
//  TonChartTonChartViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit

class TonChartViewController: GenericViewController<TonChartView> {

  // MARK: - Module

  private let presenter: TonChartPresenterInput

  // MARK: - Init

  init(presenter: TonChartPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - TonChartViewInput

extension TonChartViewController: TonChartViewInput {}

// MARK: - Private

private extension TonChartViewController {
  func setup() {}
}
