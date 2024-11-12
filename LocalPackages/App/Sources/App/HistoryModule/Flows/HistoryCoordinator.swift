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
  
  var didOpenEventDetails: ((_ wallet: Wallet, _ event: AccountEventDetailsEvent, _ isTestnet: Bool) -> Void)?
  var didDecryptComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload, _ eventId: String) -> Void)?
  var didOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let recipientResolver: RecipientResolver
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       recipientResolver: RecipientResolver
  ) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.recipientResolver = recipientResolver
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
        cacheProvider: HistoryListAllEventsCacheProvider(historyService: keeperCoreMainAssembly.servicesAssembly.historyService()),
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider())
      )
      
      let historyModule = HistoryAssembly.module(
        wallet: wallet,
        historyListViewController: listModule.view,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
      
      listModule.output.didSelectEvent = { [weak self] event in
        self?.openEventDetails(event: event, wallet: wallet)
      }
      
      listModule.output.didSelectNFT = { [weak self] wallet, nftAddress in
        guard let self else { return }
        self.openNFTDetails(wallet: wallet, address: nftAddress)
      }
      
      weak var historyInput = historyModule.input
      listModule.output.didUpdateState = { hasEvents in
        historyInput?.setHasEvents(hasEvents)
      }
      
      listModule.output.didSelectEncryptedComment = { [weak self] wallet, payload, eventId in
        self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
      }
      
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
  
  func openEventDetails(event: AccountEventDetailsEvent, wallet: Wallet) {
    didOpenEventDetails?(wallet, event, wallet.isTestnet)
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
      
      coordinator.didOpenDapp = { [weak self] url, title in
        self?.didOpenDapp?(url, title)
      }

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
  
  func decryptComment(wallet: Wallet, payload: EncryptedCommentPayload, eventId: String) {
    didDecryptComment?(wallet, payload, eventId)
  }
}
