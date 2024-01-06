//
//  WalletHeaderViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit
import TKUIKitLegacy

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
  
  func showBanner(bannerModel: WalletHeaderBannerModel) {
    customView.walletHeaderBannersContainerView.showBanner(model: bannerModel) { [weak self] in
      self?.didUpdateHeight?()
    }
    didUpdateHeight?()
  }
  
  func hideBanner(with identifier: String) {
    customView.walletHeaderBannersContainerView.hideBanner(identifier: identifier) { [weak self] in
      self?.didUpdateHeight?()
    }
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
  
  func updateTitleView(with model: TitleConnectionView.Model) {
    customView.titleView.titleConnectionView.configure(model: model)
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
  
    customView.titleView.rightButtons = [createQRScanButton()]
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
  
  func createQRScanButton() -> UIButton {
    let scanQRButton = IncreaseTapAreaUIButton(type: .system)
    scanQRButton.addTarget(self,
                           action: #selector(didTapScanQRButton),
                           for: .touchUpInside)
    scanQRButton.tapAreaInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    scanQRButton.setImage(.Icons.Buttons.scanQR, for: .normal)
    scanQRButton.tintColor = .Accent.blue
    scanQRButton.contentEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 0)
    return scanQRButton
  }
}
