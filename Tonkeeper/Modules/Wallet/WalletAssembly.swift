//
//  WalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class WalletAssembly {
  
  private let qrScannerAssembly: QRScannerAssembly
  
  init(qrScannerAssembly: QRScannerAssembly) {
    self.qrScannerAssembly = qrScannerAssembly
  }
  
  func walletRootModule(output: WalletRootModuleOutput) -> Module<UIViewController, Void> {
    let presenter = WalletRootPresenter()
    presenter.output = output
    let viewController = WalletRootViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
  
  func qrScannerModule(output: QRScannerModuleOutput) -> Module<UIViewController, Void> {
    qrScannerAssembly.qrScannerModule(output: output)
  }
}
