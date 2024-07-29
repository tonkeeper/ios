import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class CollectiblesDetailsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didClose: (() -> Void)?
  var didPerformTransaction: (() -> Void)?
  
  private weak var sendTokenCoordinator: SendTokenCoordinator?
  private weak var linkDNSCoordinator: LinkDNSCoordinator?
  private weak var renewDNSCoordinator: RenewDNSCoordinator?
  
  private let nft: NFT
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              nft: NFT,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.nft = nft
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openDetails()
  }
  
  public func handleTonkeeperDeeplink(deeplink: TonkeeperDeeplink) -> Bool {
    switch deeplink {
    case let .publish(model):
      if let sendTokenCoordinator = sendTokenCoordinator {
        return sendTokenCoordinator.handleTonkeeperPublishDeeplink(model: model)
      }
      if let linkDNSCoordinator = linkDNSCoordinator {
        return linkDNSCoordinator.handleTonkeeperPublishDeeplink(model: model)
      }
      if let renewDNSCoordinator = renewDNSCoordinator {
        return renewDNSCoordinator.handleTonkeeperPublishDeeplink(model: model)
      }
      return false
    default: return false
    }
  }
}

private extension CollectiblesDetailsCoordinator {
  func openDetails() {
    let module = CollectibleDetailsAssembly.module(
      collectibleDetailsController: keeperCoreMainAssembly.collectibleDetailsController(nft: nft),
      urlOpener: coreAssembly.urlOpener(),
      output: self
    )
    router.push(viewController: module.0)
  }
}

extension CollectiblesDetailsCoordinator: CollectibleDetailsModuleOutput {
  func collectibleDetailsDidFinish(_ collectibleDetails: any CollectibleDetailsModuleInput) {
    didClose?()
  }
  
  func collectibleDetails(_ collectibleDetails: CollectibleDetailsModuleInput, transferNFT nft: NFT) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let sendTokenCoordinator = SendModule(
      dependencies: SendModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createSendTokenCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      sendItem: .nft(nft)
    )
    
    sendTokenCoordinator.didFinish = { [weak self, weak sendTokenCoordinator, weak navigationController] in
      self?.sendTokenCoordinator = nil
      navigationController?.dismiss(animated: true)
      self?.didPerformTransaction?()
      guard let sendTokenCoordinator else { return }
      self?.removeChild(sendTokenCoordinator)
    }
    
    self.sendTokenCoordinator = sendTokenCoordinator
    
    addChild(sendTokenCoordinator)
    sendTokenCoordinator.start()
    
    self.router.rootViewController.present(navigationController, animated: true)
  }
  
  func collectibleDetailsLinkDomain(_ collectibleDetails: CollectibleDetailsModuleInput, nft: NFT) {
    let wallet = keeperCoreMainAssembly.walletAssembly.walletsStore.getState().activeWallet
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    
    let coordinator = DNSModule(
      dependencies: DNSModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createLinkDNSCoordinator(
      window: window,
      wallet: wallet,
      nft: nft,
      flow: .link
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.didPerformTransaction?()
      self?.router.dismiss()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    linkDNSCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func collectibleDetailsUnlinkDomain(_ collectibleDetails:CollectibleDetailsModuleInput, nft: NFT) {
    let wallet = keeperCoreMainAssembly.walletAssembly.walletsStore.getState().activeWallet
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    
    let coordinator = DNSModule(
      dependencies: DNSModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createLinkDNSCoordinator(window: window, wallet: wallet, nft: nft, flow: .unlink)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.didPerformTransaction?()
      self?.router.dismiss()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    linkDNSCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func collectibleDetailsRenewDomain(_ collectibleDetails: any CollectibleDetailsModuleInput, nft: NFT) {
    let wallet = keeperCoreMainAssembly.walletAssembly.walletsStore.getState().activeWallet
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    
    let coordinator = DNSModule(
      dependencies: DNSModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createRenewDNSCoordinator(
      window: window,
      wallet: wallet,
      nft: nft
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.didPerformTransaction?()
      self?.router.dismiss()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    renewDNSCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
  }
}
