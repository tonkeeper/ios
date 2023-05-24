//
//  QRScannerPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation

final class QRScannerPresenter {
  
  // MARK: - Module
  
  weak var viewInput: QRScannerViewInput?
  weak var output: QRScannerModuleOutput?
}

extension QRScannerPresenter: QRScannerPresenterInput {}
