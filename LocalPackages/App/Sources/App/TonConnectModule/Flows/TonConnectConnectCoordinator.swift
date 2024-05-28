import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore

public protocol TonConnectConnectCoordinatorConnector {
  func connect(wallet: Wallet,
               parameters: TonConnectParameters,
               manifest: TonConnectManifest) async throws
}

public struct DefaultTonConnectConnectCoordinatorConnector: TonConnectConnectCoordinatorConnector {
  private let tonConnectAppsStore: TonConnectAppsStore
  
  public func connect(wallet: Wallet, parameters: TonConnectParameters, manifest: TonConnectManifest) async throws {
    try await tonConnectAppsStore.connect(wallet: wallet, parameters: parameters, manifest: manifest)
  }
  
  public init(tonConnectAppsStore: TonConnectAppsStore) {
    self.tonConnectAppsStore = tonConnectAppsStore
  }
}

public struct BridgeTonConnectConnectCoordinatorConnector: TonConnectConnectCoordinatorConnector {
  private let tonConnectAppsStore: TonConnectAppsStore
  private let connectionResponseHandler: (TonConnectAppsStore.ConnectResult) -> Void
  
  public init(tonConnectAppsStore: TonConnectAppsStore, connectionResponseHandler: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
    self.tonConnectAppsStore = tonConnectAppsStore
    self.connectionResponseHandler = connectionResponseHandler
  }
  
  public func connect(wallet: Wallet, parameters: TonConnectParameters, manifest: TonConnectManifest) async throws {
    let response = tonConnectAppsStore.connectBridgeDapp(
      wallet: wallet,
      parameters: parameters,
      manifest: manifest
    )
    connectionResponseHandler(response)
  }
}

public final class TonConnectConnectCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didConnect: (() -> Void)?
  public var didCancel: (() -> Void)?
  
  private let connector: TonConnectConnectCoordinatorConnector
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  private let showWalletPicker: Bool
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: ViewControllerRouter,
              connector: TonConnectConnectCoordinatorConnector,
              parameters: TonConnectParameters,
              manifest: TonConnectManifest,
              showWalletPicker: Bool,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.connector = connector
    self.parameters = parameters
    self.manifest = manifest
    self.showWalletPicker = showWalletPicker
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openTonConnectConnect()
  }
}

private extension TonConnectConnectCoordinator {
  func openTonConnectConnect() {
    let module = TonConnectConnectAssembly.module(
      parameters: parameters,
      manifest: manifest,
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletStore,
      showWalletPicker: showWalletPicker
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(
      contentViewController: module.view
    )
    
    module.output.didTapWalletPicker = { [weak self, weak bottomSheetViewController] wallet in
      guard let bottomSheetViewController else { return }
      self?.openWalletPicker(
        wallet: wallet,
        fromViewController: bottomSheetViewController,
        didSelectWallet: { [weak input = module.input] wallet in
          input?.setWallet(wallet)
        }
      )
    }
    
    module.output.connect = { [weak self, weak bottomSheetViewController] connectParameters in
      guard let self, let bottomSheetViewController else { return false }
      return await self.connect(parameters: connectParameters, fromViewController: bottomSheetViewController)
    }
    
    module.output.didConnect = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss {
        self?.didConnect?()
      }
    }
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard isInteractivly else { return }
      self?.didCancel?()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func connect(
    parameters: TonConnectConnectParameters,
    fromViewController: UIViewController
  ) async -> Bool {
    guard await openConfirmation(fromViewController: fromViewController) else {
      return false
    }
    do {
      try await connector.connect(
        wallet: parameters.wallet,
        parameters: parameters.parameters,
        manifest: parameters.manifest
      )
      return true
    } catch {
      return false
    }
  }
  
  func openConfirmation(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        fromViewController.present(coordinator.router.rootViewController, animated: true)
      }
    }.value
  }
  
  func openWalletPicker(wallet: Wallet, fromViewController: UIViewController, didSelectWallet: @escaping (Wallet) -> Void) {
    let module = WalletsListAssembly.module(
      walletListController: keeperCoreMainAssembly.walletSelectWalletLisController(
        selectedWallet: wallet,
        didSelectWallet: { wallet in
          didSelectWallet(wallet)
        }
      )
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didTapAddWalletButton = { [weak self, unowned bottomSheetViewController] in
      self?.openAddWallet(router: ViewControllerRouter(rootViewController: bottomSheetViewController)) {
      }
    }
    
    module.output.didSelectWallet = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: fromViewController)
  }
  
  func openAddWallet(router: ViewControllerRouter, onAddWallets: @escaping () -> Void) {
    let module = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
      )
    )
    
    let coordinator = module.createAddWalletCoordinator(
      options: [.createRegular, .importRegular, .importWatchOnly, .importTestnet, .signer],
      router: router
    )
    coordinator.didAddWallets = {
      onAddWallets()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
