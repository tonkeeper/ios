//
//  ReceiveReceiveViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import UIKit

class ReceiveViewController: GenericViewController<ReceiveView> {

  // MARK: - Module

  private let presenter: ReceivePresenterInput

  // MARK: - Init

  init(presenter: ReceivePresenterInput) {
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

extension ReceiveViewController: ReceiveViewInput {
  func updateView(model: ReceiveView.Model) {
    customView.configure(model: model)
  }
  
  func updateQRCode(image: UIImage?) {
    customView.qrImageView.image = image
  }
}

// MARK: - Private

private extension ReceiveViewController {
  func setup() {
    let swipeButton = TKButton(configuration: .Header.button)
    swipeButton.configure(model: .init(icon: .Icons.Buttons.Header.swipe))
    swipeButton.addAction(.init(handler: { [weak self] in
      self?.presenter.didTapSwipeButton()
    }), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeButton)
    
    customView.copyButton.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
  }
  
  @objc
  func copyAddress() {
    TapticGenerator.generateCopyFeedback()
    presenter.copyAddress()
  }
}
