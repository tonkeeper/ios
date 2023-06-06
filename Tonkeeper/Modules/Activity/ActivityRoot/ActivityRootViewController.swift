//
//  ActivityRootActivityRootViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

class ActivityRootViewController: GenericViewController<ActivityRootView> {

  // MARK: - Module

  private let presenter: ActivityRootPresenterInput
  
  // MARK: - Children
  
  private let emptyViewController: ActivityEmptyViewController

  // MARK: - Init

  init(presenter: ActivityRootPresenterInput,
       emptyViewController: ActivityEmptyViewController) {
    self.presenter = presenter
    self.emptyViewController = emptyViewController
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

// MARK: - ActivityRootViewInput

extension ActivityRootViewController: ActivityRootViewInput {
  func showEmptyState() {
    customView.showEmptyState()
  }
}

// MARK: - Private

private extension ActivityRootViewController {
  func setup() {
    setupEmptyViewController()
  }
  
  func setupEmptyViewController() {
    addChild(emptyViewController)
    customView.addEmptyContentView(view: emptyViewController.view)
    emptyViewController.didMove(toParent: self)
  }
}
