//
//  SendRecipientSendRecipientViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

class SendRecipientViewController: GenericViewController<SendRecipientView> {

  // MARK: - Module

  private let presenter: SendRecipientPresenterInput

  // MARK: - Init

  init(presenter: SendRecipientPresenterInput) {
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

// MARK: - SendRecipientViewInput

extension SendRecipientViewController: SendRecipientViewInput {}

// MARK: - Private

private extension SendRecipientViewController {
  func setup() {
    title = "Recipient"
    setupCloseButton { [weak self] in
      self?.presenter.didTapCloseButton()
    }
  }
}
