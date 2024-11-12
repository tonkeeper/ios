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
              keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) {
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
    
    module.output.didTapBurn = { [weak self] nft in
      guard let self = self, let burnAddress = Address.burnAddress else {
        return
      }
      
      openTransfer(
        nft: nft,
        recipient: Recipient(recipientAddress: .raw(burnAddress), isMemoRequired: false)
      )
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
        mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
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
              mnemonicRepository: self.keeperCoreMainAssembly.secureAssembly.mnemonicsRepository()
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

      let toastTitle: String
      if self.nft.collection != nil {
        toastTitle = TKLocales.Collectibles.collectionHidden
      } else {
        toastTitle = TKLocales.Collectibles.nftHidden
      }

      DispatchQueue.main.async {
        let configuration = ToastPresenter.Configuration(title: toastTitle)
        ToastPresenter.showToast(configuration: configuration)
        self.didClose?()
      }
    }

    module.output.didTapUnverifiedNftDetails = { [weak self] in
      self?.openUnverifiedNftInfoPopup()
    }

    module.output.didTapReportSpam = { [weak self] in
      guard let self else {
        return
      }

      let toastTitle: String
      if self.nft.collection != nil {
        toastTitle = TKLocales.Collectibles.collectionMarkedAsSpam
      } else {
        toastTitle = TKLocales.Collectibles.nftMarkedAsSpam
      }

      DispatchQueue.main.async {
        let configuration = ToastPresenter.Configuration(title: toastTitle)
        ToastPresenter.showToast(configuration: configuration)
        self.didClose?()
      }
    }

    router.push(viewController: module.view)
  }

  func openTransfer(nft: NFT, recipient: Optional<Recipient> = nil) {
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
      sendItem: .nft(nft),
      recipient: recipient
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

  func openUnverifiedNftInfoPopup() {
    let viewController = InfoPopupBottomSheetViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )

    let scamNFTController = keeperCoreMainAssembly.NFTScamController(nft: nft)
    let nftManagmentStore = keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet)
    let state: NFTsManagementState.NFTState?
    if let collection = nft.collection {
      state = nftManagmentStore.getState().nftStates[.collection(collection.address)]
    } else {
      state = nftManagmentStore.getState().nftStates[.singleItem(nft.address)]
    }

    var reportSpamButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    reportSpamButton.content = .init(title: .plainString(TKLocales.NftDetails.UnverifiedNft.reportSpam))
    reportSpamButton.backgroundColors = [
      .normal: .Accent.orange,
      .highlighted: .Accent.orange.withAlphaComponent(0.64)
    ]
    reportSpamButton.action = {

    }
    var notSpamButton = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    notSpamButton.content = .init(title: .plainString(TKLocales.NftDetails.UnverifiedNft.notSpam))
    notSpamButton.action = { [weak bottomSheetViewController, nft, weak nftManagmentStore, scamNFTController] in
      Task {
        try? await scamNFTController.changeSuspiciousState(isScam: false)
        if let collection = nft.collection {
          await nftManagmentStore?.approveItem(.collection(collection.address))
        } else {
          await nftManagmentStore?.approveItem(.singleItem(nft.address))
        }

        bottomSheetViewController?.dismiss()
      }
    }

    let content = [
      TKLocales.NftDetails.UnverifiedNft.usedForSpamDescription,
      TKLocales.NftDetails.UnverifiedNft.usedForScamDescription,
      TKLocales.NftDetails.UnverifiedNft.littleInfoDescription
    ]

    var buttons = [reportSpamButton]
    if state != .approved {
      buttons.append(notSpamButton)
    }

    let configuration = configurationBuilder.commonConfiguration(
      title: TKLocales.NftDetails.unverifiedNft,
      caption: TKLocales.NftDetails.UnverifiedNft.unverifiedDescription,
      body: [.textWithTabs(content: content)],
      buttons: buttons
    )

    viewController.configuration = configuration
    let presented = router.rootViewController.presentedViewController ?? router.rootViewController
    bottomSheetViewController.present(fromViewController: presented)
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

private extension Address {
  static var burnAddress: Address? = try? Address.parse(raw: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
}
