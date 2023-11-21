//
//  TonConnectAssembly.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit
import WalletCoreKeeper

struct TonConnectAssembly {
  let walletCoreAssembly: WalletCoreAssembly
  
  func coordinator(router: Router<UIViewController>,
                   parameters: TonConnectParameters,
                   manifest: TonConnectManifest) -> TonConnectCoordinator {
    TonConnectCoordinator(
      router: router,
      walletCoreAssembly: walletCoreAssembly,
      parameters: parameters,
      manifest: manifest
    )
  }
  
  func confirmationCoordinator() -> TonConnectConfirmationCoordinator {
    let router = Router(rootViewController: UIViewController())
    let tonConnectConfirmationController = walletCoreAssembly.tonConnectConfirmationController()
    let coordinator = TonConnectConfirmationCoordinator(
      router: router,
      tonConnectConfirmationController: tonConnectConfirmationController,
      walletCoreAssembly: walletCoreAssembly
    )
    tonConnectConfirmationController.output = coordinator
    return coordinator
  }
}
