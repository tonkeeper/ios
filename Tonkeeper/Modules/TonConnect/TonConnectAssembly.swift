//
//  TonConnectAssembly.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit
import WalletCore

struct TonConnectAssembly {
  let walletCoreAssembly: WalletCoreAssembly
  
  func coordinator(router: Router<UIViewController>,
                   parameters: TCParameters,
                   manifest: TonConnectManifest) -> TonConnectCoordinator {
    TonConnectCoordinator(
      router: router,
      walletCoreAssembly: walletCoreAssembly,
      parameters: parameters,
      manifest: manifest
    )
  }
}
