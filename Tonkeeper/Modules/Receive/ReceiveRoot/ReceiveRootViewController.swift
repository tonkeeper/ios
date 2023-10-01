//
//  ReceiveReceiveViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import UIKit

class ReceiveRootViewController: GenericViewController<ReceiveRootView> {
  
  // MARK: - Module
  
  private let presenter: ReceiveRootPresenterInput
  
  // MARK: - Dependencies
  
  private let imageLoader = NukeImageLoader()
  
  // MARK: - Init
  
  init(presenter: ReceiveRootPresenterInput) {
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
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    customView.qrImageView.layoutIfNeeded()
    presenter.generateQRCode(size: customView.qrImageView.frame.size)
  }
}

// MARK: - ReceiveViewInput

extension ReceiveRootViewController: ReceiveRootViewInput {
  func updateView(model: ReceiveRootView.Model) {
    customView.configure(model: model)
  }
  
  func updateImage(_ image: Image) {
    switch image {
    case let .url(url):
      imageLoader.loadImage(imageURL: url, imageView: customView.logoImageView, size: customView.imageSize)
    case let .image(image, tintColor, backgroundColor):
      customView.logoImageView.image = image
      customView.logoImageView.tintColor = tintColor
      customView.logoImageView.backgroundColor = backgroundColor
    }
  }
  
  func updateQRCode(image: UIImage?) {
    customView.qrImageView.image = image
  }
}

// MARK: - Private

private extension ReceiveRootViewController {
  func setup() {
    let swipeButton = TKButton(configuration: .Header.button)
    swipeButton.configure(model: .init(icon: .Icons.Buttons.Header.swipe))
    swipeButton.addAction(.init(handler: { [weak self] in
      self?.presenter.didTapSwipeButton()
    }), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeButton)
    
    customView.copyButton.addTarget(
      self,
      action: #selector(didTapCopyAddress),
      for: .touchUpInside
    )
    customView.shareButton.addTarget(
      self,
      action: #selector(didTapShare),
      for: .touchUpInside
    )
  }
  
  @objc
  func didTapCopyAddress() {
    TapticGenerator.generateCopyFeedback()
    ToastController.showToast(configuration: .copied)
    presenter.copyAddress()
  }
  
  @objc
  func didTapShare() {
    let address = presenter.getAddress()
    let activityViewController = UIActivityViewController(activityItems: [address], applicationActivities: nil)
    activityViewController.overrideUserInterfaceStyle = .dark
    present(activityViewController, animated: true)
  }
}
