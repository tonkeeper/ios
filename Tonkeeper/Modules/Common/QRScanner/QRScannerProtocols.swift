//
//  QRScannerProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import QuartzCore.CALayer

protocol QRScannerModuleOutput: AnyObject {
  func qrScannerModuleDidFinish()
  func didScanQrCode(with string: String)
}

protocol QRScannerPresenterInput {
  func viewDidLoad()
  func viewDidAppear()
  func viewDidDisappear()
  func didToggleFlashligt(isSelected: Bool)
  func didTapSwipeButton()
  func openSettings()
}

protocol QRScannerViewInput: AnyObject {
  func showVideoLayer(_ layer: CALayer)
  func showCameraPermissionDenied()
}
