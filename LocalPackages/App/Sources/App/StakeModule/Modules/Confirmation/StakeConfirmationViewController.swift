//
//  StakeConfirmationViewController.swift
//
//
//  Created by Semyon on 17/05/2024.
//

import UIKit
import TKUIKit

final class StakeConfirmationViewController: GenericViewViewController<StakeConfirmationView> {
  private let viewModel: StakeConfirmationViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: StakeConfirmationViewModel) {
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

private extension StakeConfirmationViewController {
  func setup() {
    addChild(modalCardViewController)
    customView.embedContent(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak modalCardViewController] configuration in
      
    }
  }
}
