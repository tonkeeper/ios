import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit

public final class ImportWatchOnlyWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didImportWallet: (() -> Void)?
  
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let analyticsProvider: AnalyticsProvider
  private let customizeWalletModule: (_ name: String?) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(router: NavigationControllerRouter,
       analyticsProvider: AnalyticsProvider,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       customizeWalletModule: @escaping (_ name: String?) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.customizeWalletModule = customizeWalletModule
    self.analyticsProvider = analyticsProvider
    super.init(router: router)
  }

  public override func start() {
    openWatchOnlyWalletAddressInput()
  }
}

private extension ImportWatchOnlyWalletCoordinator {
  func openWatchOnlyWalletAddressInput() {
    let module = WatchOnlyWalletAddressInputAssembly.module(controller: walletsUpdateAssembly.watchOnlyWalletAddressInputController())
    
    module.output.didInputWallet = { [weak self] resolvableAddress in
      self?.openCustomizeWallet(resolvableAddress: resolvableAddress)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupSwipeDownButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view, onPopClosures: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openCustomizeWallet(resolvableAddress: ResolvableAddress) {
    let name: String?
    switch resolvableAddress {
    case .Domain(let domain, _):
      name = domain
    case .Resolved(_):
      name = nil
    }
    let module = customizeWalletModule(name)
    
    module.output.didCustomizeWallet = { [weak self] model in
      guard let self else { return }
      Task {
        await self.importWallet(
          resolvableAddress: resolvableAddress,
          model: model
        )
      }
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view)
  }
  
  func importWallet(resolvableAddress: ResolvableAddress,
                    model: CustomizeWalletModel) async {
    let addController = walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: model.icon)
    do {
      analyticsProvider.logEvent(eventKey: .importWatchOnly)
      try await addController.importWatchOnlyWallet(
        resolvableAddress: resolvableAddress,
        metaData: metaData
      )
      await MainActor.run {
        didImportWallet?()
      }
    } catch {
      print("Log: Watch only wallet import failed")
    }
  }
}
