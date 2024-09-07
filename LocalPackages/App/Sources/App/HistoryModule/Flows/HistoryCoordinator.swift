import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize
import TonSwift
import CryptoKit
import TweetNacl
import CommonCrypto
import CryptoSwift

public final class HistoryCoordinator: RouterCoordinator<NavigationControllerRouter> {
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.history
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.clock
  }
  
  public override func start() {
    openHistory()
  }
}

private extension HistoryCoordinator {
  func openHistory() {
    let module = HistoryContainerAssembly.module(keeperCoreMainAssembly: keeperCoreMainAssembly)
    
    module.output.didChangeWallet = { [weak self, keeperCoreMainAssembly] wallet in
      
      let listModule = HistoryListAssembly.module(
        wallet: wallet,
        paginationLoader: keeperCoreMainAssembly.loadersAssembly.historyAllEventsPaginationLoader(
          wallet: wallet
        ),
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider())
      )
      
      listModule.output.didSelectEvent = { [weak self] event in
        self?.openEventDetails(event: event)
      }
      
      listModule.output.didSelectNFT = { [weak self] wallet, nftAddress in
        guard let self else { return }
        Task {
          await self.openNFTDetails(wallet: wallet, address: nftAddress)
        }
      }
      
      listModule.output.didSelectEncryptedComment = { [weak self] wallet, payload in
        self?.decryptComment(wallet: wallet, payload: payload)
      }
      
      let historyModule = HistoryAssembly.module(
        wallet: wallet,
        historyListViewController: listModule.view,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
      
      historyModule.output.didTapReceive = { [weak self] wallet in
        self?.openReceive(wallet: wallet)
      }

      historyModule.output.didTapBuy = { [weak self] wallet in
        self?.openBuy(wallet: wallet)
      }
      
      module.view.historyViewController = historyModule.view
    }

    router.push(viewController: module.view, animated: false)
  }
  
  func openReceive(wallet: Wallet) {
    let module = ReceiveModule(
      dependencies: ReceiveModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).receiveModule(token: .ton, wallet: wallet)
    
    module.view.setupSwipeDownButton()
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    
    router.present(navigationController)
  }
  
  func openBuy(wallet: Wallet) {
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: ViewControllerRouter(rootViewController: self.router.rootViewController)
    )
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openEventDetails(event: AccountEventDetailsEvent) {
    let module = HistoryEventDetailsAssembly.module(
      historyEventDetailsController: keeperCoreMainAssembly.historyEventDetailsController(event: event),
      urlOpener: coreAssembly.urlOpener()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  @MainActor
  func openNFTDetails(wallet: Wallet, address: Address) {
    if let nft = try? keeperCoreMainAssembly.servicesAssembly.nftService().getNFT(address: address, isTestnet: wallet.isTestnet) {
      openDetails(wallet: wallet, nft: nft)
    } else {
      ToastPresenter.showToast(configuration: .loading)
      Task {
        guard let loaded = try? await keeperCoreMainAssembly.servicesAssembly.nftService().loadNFTs(addresses: [address], isTestnet: wallet.isTestnet),
              let nft = loaded[address] else {
          await MainActor.run {
            ToastPresenter.showToast(configuration: .failed)
          }
          return
        }
        await MainActor.run {
          ToastPresenter.hideAll()
          openDetails(wallet: wallet, nft: nft)
        }
      }
    }

    @MainActor
    func openDetails(wallet: Wallet, nft: NFT) {
      let navigationController = TKNavigationController()
      navigationController.setNavigationBarHidden(true, animated: false)
      
      let coordinator = CollectiblesDetailsCoordinator(
        router: NavigationControllerRouter(rootViewController: navigationController),
        nft: nft,
        wallet: wallet,
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )

      coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
        navigationController?.dismiss(animated: true)
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }
      
      coordinator.start()
      addChild(coordinator)
      
      router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      })
    }
  }
  
  func decryptComment(wallet: Wallet, payload: EncryptedCommentPayload) {}
  
  func getPasscode() async -> String? {
    return await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }
}
