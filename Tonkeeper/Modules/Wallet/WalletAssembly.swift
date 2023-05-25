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
    
    let headerModule = walletHeaderModule(output: presenter)
    presenter.headerInput = headerModule.input
    
    let viewController = WalletRootViewController(
      presenter: presenter,
      headerViewController: headerModule.view
    )
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
  
  func qrScannerModule(output: QRScannerModuleOutput) -> Module<UIViewController, Void> {
    qrScannerAssembly.qrScannerModule(output: output)
  }
}

private extension WalletAssembly {
  func walletHeaderModule(output: WalletHeaderModuleOutput) -> Module<UIViewController, WalletHeaderModuleInput> {
    let presenter = WalletHeaderPresenter()
    presenter.output = output
    let viewController = WalletHeaderViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
}
