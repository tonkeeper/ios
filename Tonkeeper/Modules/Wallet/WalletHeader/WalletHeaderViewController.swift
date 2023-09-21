//
//  WalletHeaderViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class WalletHeaderViewController: GenericViewController<WalletHeaderView> {
  
  // MARK: - Module
  
  private let presenter: WalletHeaderPresenterInput
  
  
  var didUpdateHeight: (() -> Void)?
  // MARK: - Init
  
  init(presenter: WalletHeaderPresenterInput) {
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
}

// MARK: - WalletHeaderViewInput

extension WalletHeaderViewController: WalletHeaderViewInput {
  func update(with model: WalletHeaderView.Model) {
    customView.configure(model: model)
    didUpdateHeight?()
  }
  
  func updateButtons(with models: [WalletHeaderButtonModel]) {
    let buttons: [IconButton] = models.map { model in
      let iconButton = IconButton()
      iconButton.configure(model: model.viewModel)
      iconButton.addAction(.init(handler: {
        model.handler?()
      }), for: .touchUpInside)
      return iconButton
    }
    customView.buttonsView.buttons = buttons
  }
  
  func updateTitle(_ title: String?) {
    customView.titleView.title = title
  }
  
  func updateConnectionState(_ model: WalletHeaderConnectionStatusView.Model?) {
    guard let model = model else {
      customView.titleView.connectionStatusView.isHidden = true
      return
    }
    customView.titleView.connectionStatusView.isHidden = false
    customView.titleView.connectionStatusView.configure(model: model)
  }
}

// MARK: - Private

private extension WalletHeaderViewController {
  func setup() {
    customView.addressButton.addTarget(
      self,
      action: #selector(didTapAddressButton),
      for: .touchUpInside
    )
    
    let scanQRButton = UIButton(type: .system)
    scanQRButton.setImage(.Icons.Buttons.scanQR, for: .normal)
    scanQRButton.tintColor = .Accent.blue
    scanQRButton.addTarget(self,
                           action: #selector(didTapScanQRButton),
                           for: .touchUpInside)
    
    customView.titleView.rightButtons = [scanQRButton]
  }
}

// MARK: - Actions

private extension WalletHeaderViewController {
  @objc
  func didTapAddressButton() {
    TapticGenerator.generateCopyFeedback()
    presenter.didTapAddressButton()
  }
  
  @objc
  func didTapScanQRButton() {
    presenter.didTapScanQRButton()
  }
}
