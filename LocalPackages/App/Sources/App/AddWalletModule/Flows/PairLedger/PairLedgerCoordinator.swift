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
    
    module.output.didConnect = { [weak self, weak bottomSheetViewController] ledgerAccounts, deviceId, deviceProductName, completion in
      guard let self, let bottomSheetViewController else { return }
      Task {
        do {
          let accounts: [(String, Address, WalletContractVersion)] = ledgerAccounts.compactMap {
            guard let contractVersion = WalletContractVersion(revision: $0.revision) else { return nil }
            do {
              let contract = try self.createContract(ledgerAccount: $0)
              return (id: $0.id, try contract.address(), contractVersion)
            } catch {
              return nil
            }
          }
          let activeWallets = try await self.walletUpdateAssembly
            .walletImportController()
            .findActiveWallets(accounts: accounts, isTestnet: false)
          let handledActiveWallets = self.handleActiveWallets(activeWalletModels: activeWallets,
                                                              ledgerAccounts: ledgerAccounts,
                                                              deviceId: deviceId)
          await MainActor.run {
            completion()
            bottomSheetViewController.dismiss(completion: {
              self.openImportCoordinator(accounts: ledgerAccounts, deviceId: deviceId, deviceProductName: deviceProductName, activeWalletModels: handledActiveWallets)
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
      self?.router.dismiss()
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
  
  private func handleActiveWallets(activeWalletModels: [ActiveWalletModel],
                                   ledgerAccounts: [LedgerAccount],
                                   deviceId: String) -> [ActiveWalletModel] {
    let sorted = activeWalletModels.sorted { lModel, rModel in
      guard let lLedgerAccount = ledgerAccounts.first(where: { $0.id == lModel.id }),
            let rLedgetAcccount = ledgerAccounts.first(where: { $0.id == rModel.id }) else {
        return true
      }
      return lLedgerAccount.path.index < rLedgetAcccount.path.index
    }
    do {
      let wallets = try walletUpdateAssembly.servicesAssembly.walletsService().getWallets()
      let addedIds = wallets.compactMap { wallet -> Int? in
        guard case let .Ledger(_, _, device) = wallet.identity.kind,
              device.deviceId == deviceId else { return nil }
        return Int(device.accountIndex)
      }
      let mapped = sorted.map { model in
        let isAdded: Bool = {
          guard let account = ledgerAccounts
            .first(where: { $0.id == model.id }) else { return false }
          return addedIds.contains(account.path.index)
        }()
        return ActiveWalletModel(
          id: model.id,
          revision: model.revision,
          address: model.address,
          isActive: model.isActive,
          balance: model.balance,
          nfts: model.nfts,
          isAdded: isAdded
        )
      }
      return mapped
    } catch {
      return sorted
    }
  }
  
  private func createContract(ledgerAccount: LedgerAccount) throws -> WalletContract {
    switch ledgerAccount.revision {
    case .v4R2:
      return WalletV4R2(publicKey: ledgerAccount.publicKey.data)
    }
  }
}

extension WalletContractVersion {
  init?(revision: LedgerWalletRevision) {
    switch revision {
    case .v4R2:
      self = .v4R2
    }
  }
}
