import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize
import TKScreenKit

public final class CollectiblesDetailsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didClose: (() -> Void)?
  var didPerformTransaction: (() -> Void)?
  var didOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
  var didRequestDeeplinkHandling: ((_ deeplink: Deeplink) -> Void)?

  private weak var sendTokenCoordinator: SendTokenCoordinator?
  private weak var linkDNSCoordinator: LinkDNSCoordinator?
  private weak var renewDNSCoordinator: RenewDNSCoordinator?
  
  private let nft: NFT
  private let wallet: Wallet
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              nft: NFT,
              wallet: Wallet,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.nft = nft
    self.wallet = wallet
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openDetails()
  }
  
  public func handleTonkeeperDeeplink(deeplink: Deeplink) -> Bool {
    switch deeplink {
    case let .publish(model):
      if let sendTokenCoordinator = sendTokenCoordinator {
        return sendTokenCoordinator.handleTonkeeperPublishDeeplink(sign: model)
      }
      if let linkDNSCoordinator = linkDNSCoordinator {
        return linkDNSCoordinator.handleTonkeeperPublishDeeplink(sign: model)
      }
      if let renewDNSCoordinator = renewDNSCoordinator {
        return renewDNSCoordinator.handleTonkeeperPublishDeeplink(sign: model)
      }
      return false
    default: return false
    }
  }
}

private extension CollectiblesDetailsCoordinator {

  func openDetails() {
    let module = NFTDetailsAssembly.module(
      wallet: wallet,
      nft: nft,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    module.output.didClose = { [weak self] in
      self?.didClose?()
    }
    
    module.output.didTapTransfer = { [weak self] _, nft in
      self?.openTransfer(nft: nft)
    }
    
    module.output.didTapLinkDomain = { [weak self] wallet, nft in
      self?.openLinkDomain(wallet: wallet, nft: nft)
    }
    
    module.output.didTapUnlinkDomain = { [weak self] wallet, nft in
      self?.openUnlinkDomain(wallet: wallet, nft: nft)
    }
    
    module.output.didTapRenewDomain = { [weak self] wallet, nft in
      self?.openRenewDomain(wallet: wallet, nft: nft)
    }

    module.output.didTapProgrammaticButton = { [weak self] url in
      guard let self = self else {
        return
      }

      PasscodeInputCoordinator.present(
        parentCoordinator: self,
        parentRouter: self.router,
        mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
        securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
        onCancel: { },
        onInput: { passcode in
          Task {
            let deeplinkParser = DeeplinkParser()

            if let deeplink = try? deeplinkParser.parse(string: url.absoluteString) {
              await MainActor.run {
                self.didRequestDeeplinkHandling?(deeplink)
              }

              return
            }

            let proofProvider = TonConnectNFTProofProvider(
              wallet: self.wallet,
              nft: self.nft,
              mnemonicRepository: self.keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository()
            )
            guard let composedURL = try await proofProvider.composeTonNFTProofURL(baseURL: url, passcode: passcode) else {
              await MainActor.run {
                let configuration = ToastPresenter.Configuration(title: TKLocales.Toast.serviceUnavailable)
                ToastPresenter.showToast(configuration: configuration)
              }
              
              return
            }

            await MainActor.run {
              self.didOpenDapp?(composedURL, nil)
            }
          }
        })
    }

    module.output.didTapOpenInTonviewer = { [weak self] context in
      guard let self = self else {
        return
      }

      let linkBuilder = TonviewerLinkBuilder(configuration: keeperCoreMainAssembly.configurationAssembly.configuration)
      guard let url = linkBuilder.buildLink(context: context, isTestnet: self.wallet.isTestnet) else {
        return
      }
      self.didOpenDapp?(url, "Tonviewer")
    }

    module.output.didHideNFT = { [weak self] in
      guard let self = self else {
        return
      }

      Task {
        let toastTitle: String
        if self.nft.collection != nil {
          toastTitle = TKLocales.Collectibles.collectionHidden
        } else {
          toastTitle = TKLocales.Collectibles.nftHidden
        }

        await MainActor.run {
          self.router.dismiss(animated: true, completion: {
            let configuration = ToastPresenter.Configuration(title: toastTitle)
            ToastPresenter.showToast(configuration: configuration)
          })
        }
      }
    }

    router.push(viewController: module.view)
  }

  func openTransfer(nft: NFT) {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let sendTokenCoordinator = SendModule(
      dependencies: SendModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createSendTokenCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      wallet: wallet,
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
  
  func openLinkDomain(wallet: Wallet, nft: NFT) {
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
  
  func openUnlinkDomain(wallet: Wallet, nft: NFT) {
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
  
  func openRenewDomain(wallet: Wallet, nft: NFT) {
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
