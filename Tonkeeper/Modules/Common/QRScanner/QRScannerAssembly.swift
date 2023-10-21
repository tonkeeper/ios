//
//  QRScannerAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit
import TKCore

struct QRScannerAssembly {
  static func qrScannerModule(urlOpener: URLOpener,
                              output: QRScannerModuleOutput) -> Module<UIViewController, Void> {
    let presenter = QRScannerPresenter(urlOpener: urlOpener)
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
