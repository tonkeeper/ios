//
//  ReceiveAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit
import WalletCoreKeeper

struct ReceiveAssembly {
  
  let walletCoreAssembly: WalletCoreAssembly
  
  func coordinator(router: NavigationRouter,
                   flow: ReceiveCoordinator.RecieveFlow) -> ReceiveCoordinator {
    ReceiveCoordinator(router: router,
                       walletCoreAssembly: walletCoreAssembly,
                       flow: flow)
  }
}

private extension ReceiveAssembly {
  var qrCodeGenerator: QRCodeGenerator {
    DefaultQRCodeGenerator()
  }
}

