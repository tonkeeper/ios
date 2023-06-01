//
//  WalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct WalletAssembly {
  
  private let qrScannerAssembly: QRScannerAssembly
  private let sendAssembly: SendAssembly
  
  init(qrScannerAssembly: QRScannerAssembly,
       sendAssembly: SendAssembly) {
    self.qrScannerAssembly = qrScannerAssembly
    self.sendAssembly = sendAssembly
  }
  
  func walletRootModule(output: WalletRootModuleOutput,
                        tokensListModuleOutput: TokensListModuleOutput) -> Module<UIViewController, Void> {
    let presenter = WalletRootPresenter(pagingContentFactory: { page in
      let module = tokensListModule(page: page, output: tokensListModuleOutput)
      return module.view
    })
    presenter.output = output
    
    let headerModule = walletHeaderModule(output: presenter)
    presenter.headerInput = headerModule.input
    
    let contentModule = walletContentModule(output: presenter)
    presenter.contentInput = contentModule.input
    
    let viewController = WalletRootViewController(
      presenter: presenter,
      headerViewController: headerModule.view,
      contentViewController: contentModule.view
    )
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
  
  func qrScannerModule(output: QRScannerModuleOutput) -> Module<UIViewController, Void> {
    qrScannerAssembly.qrScannerModule(output: output)
  }
  
  func tokensListModule(page: WalletContentPage, output: TokensListModuleOutput) -> Module<TokensListViewController, TokensListModuleInput> {
    let presenter = TokensListPresenter(sections: page.sections)
    let viewController = TokensListViewController(presenter: presenter)
    viewController.title = page.title
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
  
  func sendCoordinator(output: SendCoordinatorOutput) -> SendCoordinator {
    let navigationController = NavigationController()
    navigationController.configureAppearance()
    navigationController.isModalInPresentation = true
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = SendCoordinator(router: router,
                                      assembly: sendAssembly)
    coordinator.output = output
    return coordinator
  }
}

private extension WalletAssembly {
  func walletHeaderModule(output: WalletHeaderModuleOutput) -> Module<WalletHeaderViewController, WalletHeaderModuleInput> {
    let presenter = WalletHeaderPresenter()
    presenter.output = output
    let viewController = WalletHeaderViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
  
  func walletContentModule(output: WalletContentModuleOutput) -> Module<WalletContentViewController, WalletContentModuleInput> {
    let presenter = WalletContentPresenter()
    presenter.output = output
    let viewController = WalletContentViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
}
