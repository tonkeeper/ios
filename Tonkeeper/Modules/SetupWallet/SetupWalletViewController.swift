//
//  SetupWalletSetupWalletViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

class SetupWalletViewController: GenericViewController<SetupWalletView>, ModalCardContainerContent {

  // MARK: - Module

  private let presenter: SetupWalletPresenterInput
  
  // MARK: - Content
  
  private let contentViewController = ModalContentViewController()

  // MARK: - Init

  init(presenter: SetupWalletPresenterInput) {
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
  
  // MARK: - ModalCardContainerContent
  
  var height: CGFloat {
    contentViewController.height
  }
  
  var didUpdateHeight: (() -> Void)?
}

// MARK: - SetupWalletViewInput

extension SetupWalletViewController: SetupWalletViewInput {
  func update(with modalContentConfiguration: ModalContentViewController.Configuration) {
    contentViewController.configuration = modalContentConfiguration
  }
}

// MARK: - Private

private extension SetupWalletViewController {
  func setup() {
    setupModalContent()
  }
  
  func setupModalContent() {
    addChild(contentViewController)
    customView.embedContent(contentViewController.view)
    contentViewController.didMove(toParent: self)
    contentViewController.isRespectSafeArea = false
    contentViewController.didUpdateHeight = { [weak self] in
      self?.didUpdateHeight?()
    }
  }
}
