//
//  QRScannerProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import QuartzCore.CALayer

protocol QRScannerModuleOutput: AnyObject {}

protocol QRScannerPresenterInput {
  func viewDidLoad()
  func didToggleFlashligt(isSelected: Bool)
}

protocol QRScannerViewInput: AnyObject {
  func showVideoLayer(_ layer: CALayer)
}
