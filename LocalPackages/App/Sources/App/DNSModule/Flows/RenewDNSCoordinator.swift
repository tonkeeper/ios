import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore
import TonSwift

final class RenewDNSCoordinator: RouterCoordinator<WindowRouter> {
  
  var didCancel: (() -> Void)?
  var didFinish: (() -> Void)?
  
  private weak var signTransactionConfirmationCoordinator: SignTransactionConfirmationCoordinator?
    
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
  
  public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
    guard let signTransactionConfirmationCoordinator = signTransactionConfirmationCoordinator else { return false }
    return signTransactionConfirmationCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
  }
  
  override func start() {
    guard let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
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
          sendService: keeperCoreMainAssembly.servicesAssembly.sendService()
        )
      ),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.didFinish?()
    }
    
    self.signTransactionConfirmationCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
  }
}
