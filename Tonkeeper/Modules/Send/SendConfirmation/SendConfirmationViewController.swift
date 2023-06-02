//
//  SendConfirmationSendConfirmationViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import UIKit

class SendConfirmationViewController: GenericViewController<SendConfirmationView> {

  // MARK: - Module

  private let presenter: SendConfirmationPresenterInput
  
  // MARK: - Content
  
  private let contentViewController = ModalContentViewController()

  // MARK: - Init

  init(presenter: SendConfirmationPresenterInput) {
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
}

// MARK: - SendConfirmationViewInput

extension SendConfirmationViewController: SendConfirmationViewInput {
  func update(with configuration: ModalContentViewController.Configuration) {
    contentViewController.configuration = configuration
  }
}

// MARK: - Private

private extension SendConfirmationViewController {
  func setup() {
    setupCloseButton { [weak self] in
      self?.presenter.didTapCloseButton()
    }
    
    addChild(contentViewController)
    view.addSubview(contentViewController.view)
    contentViewController.didMove(toParent: self)
    
    contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      contentViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      contentViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
      contentViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
}
