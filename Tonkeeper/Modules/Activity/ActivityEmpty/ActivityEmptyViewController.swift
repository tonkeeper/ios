//
//  ActivityEmptyActivityEmptyViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

class ActivityEmptyViewController: GenericViewController<ActivityEmptyView> {

  // MARK: - Module

  private let presenter: ActivityEmptyPresenterInput

  // MARK: - Init

  init(presenter: ActivityEmptyPresenterInput) {
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

// MARK: - ActivityEmptyViewInput

extension ActivityEmptyViewController: ActivityEmptyViewInput {
  func updateView(model: ActivityEmptyView.Model) {
    customView.configure(model: model)
  }
}

// MARK: - Private

private extension ActivityEmptyViewController {
  func setup() {
    customView.receiveButton.addTarget(
      self,
      action: #selector(didTapReceiveButton),
      for: .touchUpInside
    )
  }
}

// MARK: - Actions

private extension ActivityEmptyViewController {
  @objc
  func didTapReceiveButton() {
    presenter.didTapReceiveButton()
  }
}
 
