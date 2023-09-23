//
//  ActivityEmptyActivityEmptyPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation
import TKUIKit

final class ActivityEmptyPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityEmptyViewInput?
  weak var output: ActivityEmptyModuleOutput?
}

// MARK: - ActivityEmptyPresenterIntput

extension ActivityEmptyPresenter: ActivityEmptyPresenterInput {
  func viewDidLoad() {
    updateView()
  }
  
  func didTapReceiveButton() {
    output?.didTapReceiveButton()
  }
}

// MARK: - ActivityEmptyModuleInput

extension ActivityEmptyPresenter: ActivityEmptyModuleInput {}

// MARK: - Private

private extension ActivityEmptyPresenter {
  func updateView() {
    let title = "Your activity\nwill be shown here".attributed(with: .h2,
                                                               alignment: .center,
                                                               color: .Text.primary)
    let description = "Make your first transaction!".attributed(with: .body1,
                                                                alignment: .center,
                                                                color: .Text.secondary)
    let model = ActivityEmptyView.Model(title: title,
                                        description: description,
                                        buyButtonTitle: "Buy Toncoin",
                                        receiveButtonTitle: "Receive")
    viewInput?.updateView(model: model)
  }
}
