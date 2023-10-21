//
//  QRScannerViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit
import SwiftUI
import AVFoundation

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
    presenter.viewDidLoad()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    presenter.viewDidAppear()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    presenter.viewDidDisappear()
  }
}

// MARK: - QRScannerViewInput

extension QRScannerViewController: QRScannerViewInput {
  func showVideoLayer(_ layer: CALayer) {
    customView.setVideoPreviewLayer(layer)
  }
  
  func showCameraPermissionDenied() {
    let viewController = UIHostingController(rootView: NoCameraPermissionView(buttonHandler: { [weak self] in
      self?.presenter.openSettings()
    }))
    addChild(viewController)
    customView.setCameraPermissionDeniedView(viewController.view)
    viewController.didMove(toParent: self)
  }
}

// MARK: - Private

private extension QRScannerViewController {
  func setup() {
    customView.flashlightButton.didToggle = { [weak self] in
      self?.presenter.didToggleFlashligt(isSelected: $0)
    }
    
    customView.titleLabel.text = "Scan QR code"
    
    let swipeDownButton = QRScannerSwipeDownButton()
    swipeDownButton.addTarget(self, action: #selector(didTapSwipeDownButton), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeDownButton)
  }
  
  @objc
  func didTapSwipeDownButton() {
    self.presenter.didTapSwipeButton()
  }
}
