//
//  StakeInfoViewController.swift
//
//
//  Created by Semyon on 18/05/2024.
//

import UIKit
import TKUIKit

final class StakeInfoViewController: GenericViewViewController<StakeConfirmationView> {
  private let viewModel: StakeInfoViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: StakeInfoViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewModel.viewWillDisappear()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
}

private extension StakeInfoViewController {
  func setup() {
    title = "Tonstakers"
    addChild(modalCardViewController)
    customView.embedContent(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak modalCardViewController] configuration in
      modalCardViewController?.configuration = configuration
    }
  }
}

