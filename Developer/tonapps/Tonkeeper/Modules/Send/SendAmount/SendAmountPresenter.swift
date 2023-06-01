//
//  SendAmountSendAmountPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

final class SendAmountPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendAmountViewInput?
  weak var output: SendAmountModuleOutput?
}

// MARK: - SendAmountPresenterIntput

extension SendAmountPresenter: SendAmountPresenterInput {
  func viewDidLoad() {
    updateTitle()
  }
  
  func didTapCloseButton() {
    output?.sendAmountModuleDidTapCloseButton()
  }
}

// MARK: - SendAmountModuleInput

extension SendAmountPresenter: SendAmountModuleInput {}

// MARK: - Private

private extension SendAmountPresenter {
  func updateTitle() {
    let model = SendAmountTitleView.Model(title: "Amount",
                                          subtitle: "To: EQCc…9ZLD")
    viewInput?.updateTitleView(model: model)
  }
}
