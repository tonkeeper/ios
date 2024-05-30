import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore
import TonSwift

final class RenewDNSCoordinator: RouterCoordinator<WindowRouter> {
  
  var didCancel: (() -> Void)?
  var didFinish: (() -> Void)?
    
  private let nft: NFT
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: WindowRouter,
       nft: NFT,
       wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.nft = nft
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    let wallet = self.keeperCoreMainAssembly.walletAssembly.walletStore.activeWallet
    let coordinator = SignTransactionConfirmationCoordinator(
      router: router,
      wallet: wallet,
      confirmator: RenewDNSSignTransactionConfirmationCoordinatorConfirmator(
        nft: nft,
        sendService: keeperCoreMainAssembly.servicesAssembly.sendService()
      ),
      confirmTransactionController: keeperCoreMainAssembly.confirmTransactionController(
        wallet: wallet,
        bocProvider: RenewDNSConfirmTransactionControllerBocProvider(
          nft: nft,
          sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
          signClosure: { transfer in
            try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
          }
        )
      ),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.didCancel?()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator] in
      self?.didFinish?()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
