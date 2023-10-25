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
//    
////    let vc = ModalCardViewController()
//    let headerView = TonConnectModalHeaderView()
////
//    let headerConfigurationItems: [ModalCardViewController.Configuration.Item] = [
//      .customView(headerView, bottomSpacing: 20),
//      .text(.init(text: "Connect to StickerFace?".attributed(with: .h2, alignment: .center, color: .Text.primary),
//                  numberOfLines: 1),
//            bottomSpacing: 4),
//      .text(.init(text: "stickerface.io is requesting access to your wallet address EQF2…G21Z v4R2.".attributed(with: .body1, alignment: .center, color: .Text.secondary), numberOfLines: 0), bottomSpacing: 16)
//    ]
//    let header = ModalCardViewController.Configuration.Header(items: headerConfigurationItems)
//
//    let actionBarItems: [ModalCardViewController.Configuration.Item] = [
//      .button(.init(title: "Connect wallet",
//                    configuration: .primaryLarge,
//                    isEnabled: true,
//                    isActivity: false,
//                    tapAction: { isActivity, isSuccess in
//                      isActivity(true)
//                      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                        isSuccess(true)
//                      }
//                    },
//                    completionAction: { isSuccess in
//                      if isSuccess {
////                        vc.dismiss(animated: true)
//                      }
//                    }),
//              bottomSpacing: 16),
//      .text(.init(text: "Be sure to check the service address before connecting the wallet.".attributed(with: .body2, alignment: .center, color: .Text.tertiary), numberOfLines: 0), bottomSpacing: 16)
//    ]
//
//    let actionBar = ModalCardViewController.Configuration.ActionBar(items: actionBarItems)
//    let configuration = ModalCardViewController.Configuration(header: header, actionBar: actionBar)
//    viewInput?.update(with: configuration)
  }
}

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
                    tapAction: { isActivity, isSuccess in
                      isActivity(true)
                      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isSuccess(true)
                      }
                    },
                    completionAction: { isSuccess in
                      if isSuccess {
                        
                      }
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
