//
//  SendConfirmationSendConfirmationPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import Foundation

final class SendConfirmationPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendConfirmationViewInput?
  weak var output: SendConfirmationModuleOutput?
}

// MARK: - SendConfirmationPresenterIntput

extension SendConfirmationPresenter: SendConfirmationPresenterInput {
  func viewDidLoad() {
    update()
  }
  
  func didTapCloseButton() {
    output?.sendConfirmationModuleDidTapCloseButton()
  }
}

// MARK: - SendConfirmationModuleInput

extension SendConfirmationPresenter: SendConfirmationModuleInput {}

// MARK: - Private

private extension SendConfirmationPresenter {
  func update() {
        let config = ModalContentViewController.Configuration(header: .init(title: "TON transfer", description: "Confirm action"),
                                                              listItems: [
                                                                .init(left: "Recipient", rightTop: "kachemirova.ton", rightBottom: nil),
                                                                .init(left: "Recipient address", rightTop: "EQCc…9ZLD", rightBottom: nil),
                                                                .init(left: "Amount", rightTop: "5,754.32 TON", rightBottom: "$ 6,328.81"),
                                                                .init(left: "Fee", rightTop: "≈ 0.007 TON", rightBottom: " ≈ $ 0.03"),
                                                                .init(left: "Comment", rightTop: "Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!Thanks!", rightBottom: nil),
                                                              ],
                                                              actionBar: .init(items: [.buttons([.init(title: "Confirm and send",
                                                                                                       configuration: .primaryLarge,
                                                                                                       tapAction: nil)]),
                                                                                       .buttons([.init(title: "Cancel", configuration: .secondaryLarge, tapAction: nil), .init(title: "Confirm", configuration: .primaryLarge, tapAction: nil)])]))
    viewInput?.update(with: config)
  }
}
