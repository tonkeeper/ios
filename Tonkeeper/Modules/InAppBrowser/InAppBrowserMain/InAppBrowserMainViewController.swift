//
//  InAppBrowserMainInAppBrowserMainViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import UIKit

class InAppBrowserMainViewController: GenericViewController<InAppBrowserMainView> {

  // MARK: - Module

  private let presenter: InAppBrowserMainPresenterInput

  // MARK: - Init

  init(presenter: InAppBrowserMainPresenterInput) {
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

// MARK: - InAppBrowserMainViewInput

extension InAppBrowserMainViewController: InAppBrowserMainViewInput {}

// MARK: - Private

private extension InAppBrowserMainViewController {
  func setup() {}
}
