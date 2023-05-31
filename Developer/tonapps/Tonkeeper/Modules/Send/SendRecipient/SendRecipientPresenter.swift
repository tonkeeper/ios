//
//  SendRecipientSendRecipientPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

final class SendRecipientPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendRecipientViewInput?
  weak var output: SendRecipientModuleOutput?
}

// MARK: - SendRecipientPresenterIntput

extension SendRecipientPresenter: SendRecipientPresenterInput {
  func viewDidLoad() {}
  
  func didTapCloseButton() {
    output?.didTapCloseButton()
  }
}

// MARK: - SendRecipientModuleInput

extension SendRecipientPresenter: SendRecipientModuleInput {}

// MARK: - Private

private extension SendRecipientPresenter {}
