//
//  TonConnectPopupPresenter.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import Foundation
import WalletCore

final class TonConnectPopupPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonConnectPopupViewInput?
  weak var output: TonConnectPopupModuleOutput?
  
  // MARK: - Dependencies

  private let tonConnectController: TonConnectController
  
  init(tonConnectController: TonConnectController) {
    self.tonConnectController = tonConnectController
  }
}

// MARK: - TonConnectPopupPresenterInput

extension TonConnectPopupPresenter: TonConnectPopupPresenterInput {
  func viewDidLoad() {
    updateContent()
  }
}

// MARK: - TonConnectPopupModuleInput

extension TonConnectPopupPresenter: TonConnectPopupModuleInput {}

// MARK: - Private

private extension TonConnectPopupPresenter {
  func updateContent() {
    guard let viewInput = viewInput else { return }
    let model = tonConnectController.getPopUpModel()
    let headerView = viewInput.getHeaderView(appIconURL: model.appImageURL)
    let title = "Connect to \(model.name)"
      .attributed(with: .h2,
                  alignment: .center,
                  color: .Text.primary)
    let description = createDescriptionString(
      host: model.host ?? "",
      wallet: model.wallet,
      revision: model.revision
    )
    let headerItems: [ModalCardViewController.Configuration.Item] = [
      .customView(headerView, bottomSpacing: 20),
      .text(.init(text: title,
                  numberOfLines: 1),
            bottomSpacing: 4),
      .text(.init(text: description,
                  numberOfLines: 0),
            bottomSpacing: 16)
      
    ]
    let actionBarItems: [ModalCardViewController.Configuration.Item] = [
      .button(.init(title: .buttonTitle,
                    configuration: .primaryLarge,
                    isEnabled: true,
                    isActivity: false,
                    tapAction: { [weak self] isActivityClosure, isSuccessClosure in
                      guard let self = self else { return }
                      isActivityClosure(true)
                      Task {
                        let isSuccess = await self.handleConnectButtonTap()
                        await MainActor.run {
                          isSuccessClosure(isSuccess)
                        }
                      }
                    },
                    completionAction: { [weak self] isSuccess in
                      guard let self = self,
                            isSuccess else { return }
                      self.output?.tonConnectPopupModuleDidConnect(self)
                    }),
              bottomSpacing: 16),
      .text(.init(text: .footerText,
                  numberOfLines: 0),
            bottomSpacing: 16)
    ]
    
    let configuration = ModalCardViewController.Configuration(
      header: .init(items: headerItems),
      actionBar: .init(items: actionBarItems)
    )
    viewInput.update(with: configuration)
  }
  
  func createDescriptionString(host: String,
                               wallet: String,
                               revision: String) -> NSAttributedString {
    let leftPart = "\(host) is requesting access to your wallet address "
      .attributed(with: .body1,
                  alignment: .center,
                  color: .Text.secondary)
    let addressPart = wallet
      .attributed(with: .body1,
                  alignment: .center,
                  color: .Text.tertiary)
    let revisionPart = " \(revision)"
      .attributed(with: .body1,
                  alignment: .center,
                  color: .Text.secondary)
    let result = NSMutableAttributedString(attributedString: leftPart)
    result.append(addressPart)
    result.append(revisionPart)
    return result
  }
  
  func handleConnectButtonTap() async -> Bool {
    guard let output = output else { return false }
    let isConfirmed = await output.tonConnectPopupModuleConfirmation(self)
    guard isConfirmed else { return false }
    do {
      try await tonConnectController.connect()
      return true
    } catch {
      return false
    }
  }
}

private extension String {
  static let buttonTitle = "Connect wallet"
}

private extension NSAttributedString {
  static var footerText: NSAttributedString {
    "Be sure to check the service address before connecting the wallet."
      .attributed(with: .body2,
                  alignment: .center,
                  color: .Text.tertiary
      )
  }
}
