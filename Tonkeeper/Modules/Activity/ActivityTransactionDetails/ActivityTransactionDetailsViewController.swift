//
//  ActivityTransactionDetailsActivityTransactionDetailsViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import UIKit

class ActivityTransactionDetailsViewController: GenericViewController<ActivityTransactionDetailsView>,
                                                ScrollableModalCardContainerContent {
  
  // MARK: - Module

  private let presenter: ActivityTransactionDetailsPresenterInput
  
  // MARK: - Children
  
  private let modalCardViewController = ModalCardViewController()

  // MARK: - Init

  init(presenter: ActivityTransactionDetailsPresenterInput) {
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
  
  // MARK: - ScrollableModalCardContainerContent
  
  var height: CGFloat {
    modalCardViewController.height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var scrollView: UIScrollView {
    modalCardViewController.scrollView
  }
}

// MARK: - ActivityTransactionDetailsViewInput

extension ActivityTransactionDetailsViewController: ActivityTransactionDetailsViewInput {
  func update(with modalContentConfiguration: ModalCardViewController.Configuration) {
    modalCardViewController.configuration = modalContentConfiguration
  }
  
  func updateOpenTransactionButton(with model: TKButtonControl<OpenTransactionTKButtonContentView>.Model) {
    customView.openTransactionButton.configure(model: model)
  }
}

// MARK: - Private

private extension ActivityTransactionDetailsViewController {
  func setup() {
    setupModalContent()
  }
  
  func setupModalContent() {
    customView.embedContent(modalCardViewController.view)
    modalCardViewController.didUpdateHeight = { [weak self] in
      self?.didUpdateHeight?()
    }
  }
}
