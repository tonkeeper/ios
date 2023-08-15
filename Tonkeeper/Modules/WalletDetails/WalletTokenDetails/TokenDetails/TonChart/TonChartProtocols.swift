//
//  TonChartTonChartProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import Foundation

protocol TonChartModuleOutput: AnyObject {}

protocol TonChartModuleInput: AnyObject {}

protocol TonChartPresenterInput {
  func viewDidLoad()
}

protocol TonChartViewInput: AnyObject {}