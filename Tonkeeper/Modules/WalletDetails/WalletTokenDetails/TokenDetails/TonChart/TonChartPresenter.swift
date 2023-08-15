//
//  TonChartTonChartPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import Foundation

final class TonChartPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonChartViewInput?
  weak var output: TonChartModuleOutput?
}

// MARK: - TonChartPresenterIntput

extension TonChartPresenter: TonChartPresenterInput {
  func viewDidLoad() {}
}

// MARK: - TonChartModuleInput

extension TonChartPresenter: TonChartModuleInput {}

// MARK: - Private

private extension TonChartPresenter {}
