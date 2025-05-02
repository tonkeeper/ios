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
  
  var passcodeProvider: (() async -> String?)?
  var didOpenTonEventDetails: ((_ wallet: Wallet, _ event: AccountEventDetailsEvent, _ isTestnet: Bool) -> Void)?
  var didOpenTronEventDetails: ((_ wallet: Wallet, _ event: TronTransaction, _ isTestnet: Bool) -> Void)?
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
        historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider()),
        filter: .all,
        emptyViewProvider: { filter in
          switch filter {
          case .all:
            let emptyViewController = TKEmptyViewController()
            emptyViewController.configure(
              model: TKEmptyViewController.Model(
                title: TKLocales.History.Placeholder.title,
                caption: TKLocales.History.Placeholder.subtitle,
                buttons: [
                  TKEmptyViewController.Model.Button(
                    title: TKLocales.History.Placeholder.Buttons.buy,
                    action: { [weak self] in
                      guard let self else { return }
                      self.openBuy(wallet: wallet)
                    }
                  ),
                  TKEmptyViewController.Model.Button(
                    title: TKLocales.History.Placeholder.Buttons.receive,
                    action: { [weak self] in
                      guard let self else { return }
                      self.openReceive(wallet: wallet)
                    }
                  )]
              )
            )
            return .viewController(emptyViewController)
          default:
            return nil
          }
        }
      )
      
      let historyModule = HistoryAssembly.module(
        wallet: wallet,
        historyListViewController: listModule.view,
        historyListModuleInput: listModule.input,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )

      weak var historyModuleInput = historyModule.input
      
      listModule.output.didSelectEvent = { [weak self] event in
        self?.openEventDetails(event: event, wallet: wallet)
      }
      
      listModule.output.didSelectNFT = { [weak self] wallet, nftAddress in
        guard let self else { return }
        self.openNFTDetails(wallet: wallet, address: nftAddress)
      }
      
      listModule.output.didSelectEncryptedComment = { [weak self] wallet, payload, eventId in
        self?.decryptComment(wallet: wallet, payload: payload, eventId: eventId)
      }
      
      listModule.output.didUpdateState = { state in
        historyModuleInput?.setHistoryListState(state)
      }
      
      module.view.historyViewController = historyModule.view
    }

    router.push(viewController: module.view, animated: false)
  }
  
  func openReceive(wallet: Wallet) {
    guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else { return }

    var tokens: [Token] = [.ton(.ton)]
    if wallet.isTronAvailable {
      tokens.append(.usdtTron)
    }
    
    let module = ReceiveAssembly.module(
      tokens: tokens,
      wallet: wallet,
      keeperCoreAssembly: keeperCoreMainAssembly
    )
    
    module.output.didSelectInactiveTRC20 = { [weak self] in
      self?.openReceiveTRC20Popup(wallet: $0,
                                  enableCompletion: {
        module.input.selectToken(token: .usdtTron)
      })
    }
    
    module.view.setupSwipeDownButton()
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.setNavigationBarHidden(true, animated: false)
    
    router.present(navigationController)
  }
  
  func openBuy(wallet: Wallet) {
    guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else { return }
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: ViewControllerRouter(rootViewController: self.router.rootViewController)
    )

    coordinator.didClose = { [weak coordinator, weak self] in
      self?.removeChild(coordinator)
    }

    addChild(coordinator)
    coordinator.start()
  }
  
  func openEventDetails(event: HistoryListSelectedEvent, wallet: Wallet) {
    switch event {
    case .tonEvent(let accountEventDetailsEvent):
      didOpenTonEventDetails?(wallet, accountEventDetailsEvent, wallet.isTestnet)
    case .tronEvent(let tronTransaction):
      didOpenTronEventDetails?(wallet, tronTransaction, wallet.isTestnet)
    }
  }
  
  func openReceiveTRC20Popup(wallet: Wallet,
                             enableCompletion: @escaping () -> Void) {
    guard let passcodeProvider else { return }
    let module = ReceiveTRC20PopupAssembly.module(wallet: wallet,
                                                  keeperCoreAssembly: keeperCoreMainAssembly,
                                                  passcodeProvider: passcodeProvider)
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
    
    module.output.didFinish = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    module.output.didEnable = {
      enableCompletion()
    }
  }
  
  @MainActor
  func openNFTDetails(wallet: Wallet, address: Address) {
    guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else { return }
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
    guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else { return }
    didDecryptComment?(wallet, payload, eventId)
  }
}
