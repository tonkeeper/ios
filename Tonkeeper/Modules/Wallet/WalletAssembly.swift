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
  
  let sendAssembly: SendAssembly
  let receiveAssembly: ReceiveAssembly
  let walletTokenDetailsAssembly: WalletTokenDetailsAssembly
  let collectibleAssembly: CollectibleAssembly
  let inAppBrowserAssembly: InAppBrowserAssembly
  
  private var walletBalanceModelMapper: WalletBalanceModelMapper {
    WalletBalanceModelMapper()
  }
  
  init(walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly,
       receiveAssembly: ReceiveAssembly,
       inAppBrowserAssembly: InAppBrowserAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
    self.receiveAssembly = receiveAssembly
    self.inAppBrowserAssembly = inAppBrowserAssembly
    self.walletTokenDetailsAssembly = WalletTokenDetailsAssembly(
      walletCoreAssembly: walletCoreAssembly,
      sendAssembly: sendAssembly,
      receiveAssembly: receiveAssembly,
      inAppBrowserAssembly: inAppBrowserAssembly
    )
    self.collectibleAssembly = CollectibleAssembly(walletCoreAssembly: walletCoreAssembly,
                                                   sendAssembly: sendAssembly)
  }
  
  func walletRootModule(output: WalletRootModuleOutput) -> Module<UIViewController, Void> {    
    let presenter = WalletRootPresenter(keeperController: walletCoreAssembly.keeperController,
                                        walletBalanceController: walletCoreAssembly.balanceController,
                                        pageContentProvider: .init(factory: { page, output in
      let module = tokensListModule(page: page, output: output)
      return (PagingContentContainer(pageContentViewController: module.view),
              module.input)
    }),
                                        appStateTracker: walletCoreAssembly.coreAssembly.appStateTracker,
                                        reachabilityTracker: walletCoreAssembly.coreAssembly.reachabilityTracker)
  
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
    QRScannerAssembly.qrScannerModule(
      urlOpener: walletCoreAssembly.coreAssembly.urlOpener(),
      output: output
    )
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
                       recipient: Recipient?) -> SendCoordinator {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = sendAssembly.coordinator(
      router: router,
      token: .ton,
      recipient: recipient
    )
    coordinator.output = output
    return coordinator
  }
  
  func receieveCoordinator(output: ReceiveCoordinatorOutput,
                           address: String) -> ReceiveCoordinator {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    
    let coordinator = receiveAssembly.coordinator(
      router: router,
      flow: .any)
    coordinator.output = output
    
    return coordinator
  }
  
  func buyCoordinator() -> BuyCoordinator {
    let modalCardContainerViewController = ModalCardContainerViewController()
    modalCardContainerViewController.headerSize = .big
    let router = Router(rootViewController: modalCardContainerViewController)
    let coordinator = BuyCoordinator(router: router,
                                     walletCoreAssembly: walletCoreAssembly)
    return coordinator
  }
  
  var deeplinkParser: DeeplinkParser {
    walletCoreAssembly.deeplinkParser(
      handlers:
        [walletCoreAssembly.tonConnectDeeplinkHandler,
         walletCoreAssembly.tonDeeplinkHandler]
    )
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
