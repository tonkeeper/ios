//
//  QRScannerAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class QRScannerAssembly {
  func qrScannerModule(output: QRScannerModuleOutput) -> Module<UIViewController, Void> {
    let presenter = QRScannerPresenter()
    presenter.output = output
    let viewController = QRScannerViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    
    let navigationController = UINavigationController(rootViewController: viewController)
    navigationController.navigationBar.standardAppearance = appearance
    return Module(view: navigationController, input: Void())
  }
}
