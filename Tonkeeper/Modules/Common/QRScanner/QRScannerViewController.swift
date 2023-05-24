//
//  QRScannerViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class QRScannerViewController: GenericViewController<QRScannerView> {
  
  // MARK: - Module
  
  private let presenter: QRScannerPresenterInput
  
  // MARK: - Init
  
  init(presenter: QRScannerPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
}

// MARK: - QRScannerViewInput

extension QRScannerViewController: QRScannerViewInput {}

// MARK: - Private

private extension QRScannerViewController {
  func setup() {}
}
