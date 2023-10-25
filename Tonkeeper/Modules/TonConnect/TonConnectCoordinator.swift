//
//  TonConnectCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit
import WalletCore

final class TonConnectCoordinator: Coordinator<Router<UIViewController>> {
  
  private let walletCoreAssembly: WalletCoreAssembly
  private let parameters: TCParameters
  private let manifest: TonConnectManifest
  
  init(router: Router<UIViewController>,
       walletCoreAssembly: WalletCoreAssembly,
       parameters: TCParameters,
       manifest: TonConnectManifest) {
    self.walletCoreAssembly = walletCoreAssembly
    self.parameters = parameters
    self.manifest = manifest
    super.init(router: router)
  }
  
  override func start() {
    openTonConnectPopup()
  }
}

private extension TonConnectCoordinator {
  func openTonConnectPopup() {
    let module = TonConnectPopupAssembly.module(
      tonConnectController: walletCoreAssembly.tonConnectController(
        parameters: parameters,
        manifest: manifest
      ),
      output: self
    )

    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    initialPresentable = modalCardContainerViewController
  }
}

// MARK: - TonConnectPopupModuleOutput

extension TonConnectCoordinator: TonConnectPopupModuleOutput {
  
}
