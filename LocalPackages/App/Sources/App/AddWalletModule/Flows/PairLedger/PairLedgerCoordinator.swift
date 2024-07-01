import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKCoordinator
import TonSwift
import TonTransport

public final class PairLedgerCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didPaired: (() -> Void)?
  
  private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let ledgerImportCoordinatorProvider: (NavigationControllerRouter, [LedgerAccount], [ActiveWalletModel], String) -> LedgerImportCoordinator
  
  init(walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: ViewControllerRouter,
       ledgerImportCoordinatorProvider: @escaping (NavigationControllerRouter, [LedgerAccount], [ActiveWalletModel], String) -> LedgerImportCoordinator) {
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    self.ledgerImportCoordinatorProvider = ledgerImportCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openConnectLedger()
  }
}

private extension PairLedgerCoordinator {
  func openConnectLedger() {
    let module = LedgerConnectAssembly.module(coreAssembly: coreAssembly)
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard !isInteractivly else {
        self?.didCancel?()
        return
      }
    }
    
    module.output.didCancel = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.didCancel?()
      })
    }
    
    module.output.didConnect = { [weak self, weak bottomSheetViewController] accounts, deviceId, deviceProductName, completion in
      guard let self, let bottomSheetViewController else { return }
      Task {
        do {
          let activeWallets = try await self.walletUpdateAssembly.walletImportController().findActiveWallets(ledgerAccounts: accounts, deviceId: deviceId)
          await MainActor.run {
            completion()
            bottomSheetViewController.dismiss(completion: {
              self.openImportCoordinator(accounts: accounts, deviceId: deviceId, deviceProductName: deviceProductName, activeWalletModels: activeWallets)
            })
          }
        } catch {
          await MainActor.run {
            completion()
          }
        }
      }
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openImportCoordinator(accounts: [LedgerAccount], deviceId: String, deviceProductName: String, activeWalletModels: [ActiveWalletModel]) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let coordinator = ledgerImportCoordinatorProvider(
      NavigationControllerRouter(
        rootViewController: navigationController
      ),
      accounts,
      activeWalletModels,
      deviceProductName
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didImport = { [weak self] accounts, model in
      guard let self else { return }
      Task {
        do {
          try await self.importWallet(
            accounts: accounts,
            deviceId: deviceId,
            deviceProductName: deviceProductName,
            model: model)
          await MainActor.run {
            self.didPaired?()
          }
        } catch {
          print("Log: Wallet import failed \(error)")
        }
      }
    }
    
    addChild(coordinator)
    coordinator.start()
    self.router.present(navigationController)
  }
  
  func importWallet(accounts: [LedgerAccount],
                    deviceId: String,
                    deviceProductName: String,
                    model: CustomizeWalletModel) async throws {
    let addController = walletUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: model.icon)
    try addController.importLedgerWallets(
      accounts: accounts,
      deviceId: deviceId,
      deviceProductName: deviceProductName,
      metaData: metaData
    )
  }
}
