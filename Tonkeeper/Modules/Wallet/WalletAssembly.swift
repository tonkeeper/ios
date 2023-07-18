//
//  WalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import WalletCore

struct WalletAssembly {
  
  let walletCoreAssembly: WalletCoreAssembly
  
  let qrScannerAssembly: QRScannerAssembly
  let sendAssembly: SendAssembly
  let receiveAssembly: ReceiveAssembly
  let buyAssembly: BuyAssembly
  let walletTokenDetailsAssembly: WalletTokenDetailsAssembly
  
  private var walletBalanceModelMapper: WalletBalanceModelMapper {
    WalletBalanceModelMapper()
  }
  
  init(walletCoreAssembly: WalletCoreAssembly,
       qrScannerAssembly: QRScannerAssembly,
       sendAssembly: SendAssembly,
       receiveAssembly: ReceiveAssembly,
       buyAssembly: BuyAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.qrScannerAssembly = qrScannerAssembly
    self.sendAssembly = sendAssembly
    self.receiveAssembly = receiveAssembly
    self.buyAssembly = buyAssembly
    self.walletTokenDetailsAssembly = WalletTokenDetailsAssembly(walletCoreAssembly: walletCoreAssembly)
  }
  
  func walletRootModule(output: WalletRootModuleOutput) -> Module<UIViewController, Void> {    
    let presenter = WalletRootPresenter(keeperController: walletCoreAssembly.keeperController,
                                        walletBalanceController: walletCoreAssembly.balanceController,
                                        pageContentProvider: .init(factory: { page, output in
      let module = tokensListModule(page: page, output: output)
      return (PagingContentContainer(pageContentViewController: module.view),
              module.input)
    }))
  
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
    let viewController = TokensListViewController(presenter: presenter,
                                                  imageLoader: NukeImageLoader())
    viewController.title = page.title
    presenter.viewInput = viewController
    presenter.output = output
    return Module(view: viewController, input: presenter)
  }
  
  func sendCoordinator(output: SendCoordinatorOutput,
                       address: String?) -> SendCoordinator {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    navigationController.isModalInPresentation = true
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = SendCoordinator(
      router: router,
      walletCoreAssembly: walletCoreAssembly,
      token: .ton,
      address: address
    )
    coordinator.output = output
    return coordinator
  }
  
  func receieveCoordinator(output: ReceiveCoordinatorOutput,
                           address: String) -> ReceiveCoordinator {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = ReceiveCoordinator(router: router,
                                         assembly: receiveAssembly,
                                         flow: .any,
                                         address: address)
    coordinator.output = output
    return coordinator
  }
  
  func buyCoordinator() -> BuyCoordinator {
    let modalCardContainerViewController = ModalCardContainerViewController()
    modalCardContainerViewController.headerSize = .big
    let router = Router(rootViewController: modalCardContainerViewController)
    let coordinator = BuyCoordinator(router: router,
                                     assembly: buyAssembly)
    return coordinator
  }
  
  var deeplinkParser: DeeplinkParser {
    walletCoreAssembly.deeplinkParser
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
    let presenter = WalletContentPresenter(walletBalanceModelMapper: walletBalanceModelMapper)
    presenter.output = output
    let viewController = WalletContentViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: presenter)
  }
}
