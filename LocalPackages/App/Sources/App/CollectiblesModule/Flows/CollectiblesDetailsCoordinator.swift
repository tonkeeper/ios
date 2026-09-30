import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class CollectiblesDetailsCoordinator: RouterCoordinator<NavigationControllerRouter> {
    enum PresentationStyle: Equatable {
        case modal
        case pushed
    }

    var didClose: (() -> Void)?
    var didPerformTransaction: (() -> Void)?
    var didOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
    var didRequestDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?
    var didRequestDepositTon: (() -> Void)?

    private weak var sendTokenCoordinator: SendCoordinator?
    private weak var linkDNSCoordinator: LinkDNSCoordinator?
    private weak var renewDNSCoordinator: RenewDNSCoordinator?

    private let nft: NFT
    private let wallet: Wallet
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let presentationStyle: PresentationStyle

    convenience init(
        router: NavigationControllerRouter,
        nft: NFT,
        wallet: Wallet,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.init(
            router: router,
            nft: nft,
            wallet: wallet,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            presentationStyle: .modal
        )
    }

    init(
        router: NavigationControllerRouter,
        nft: NFT,
        wallet: Wallet,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        presentationStyle: PresentationStyle
    ) {
        self.nft = nft
        self.wallet = wallet
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.presentationStyle = presentationStyle
        super.init(router: router)
    }

    override func start() {
        openDetails()
    }

    func handleTonkeeperDeeplink(deeplink: Deeplink) -> Bool {
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
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            navigationButton: presentationStyle.navigationButton
        )
        module.output.didClose = { [weak self] in
            self?.close()
        }

        module.output.didTapTransfer = { [weak self] _, nft in
            self?.openTransfer(nft: nft)
        }

        module.output.didTapBurn = { [weak self] nft in
            guard let self = self, let burnAddress = FriendlyAddress.burnAddress else {
                return
            }

            openTransfer(
                nft: nft,
                recipient: .ton(TonRecipient(recipientAddress: .friendly(burnAddress), isMemoRequired: false, isScam: false))
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
                mnemonicAccess: keeperCoreMainAssembly.secureAssembly.mnemonicAccess,
                securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
                analyticsProvider: self.coreAssembly.analyticsProvider,
                onCancel: {},
                onInput: { [weak self] passcode in
                    guard let self else { return }
                    Task { @MainActor [self] in
                        if let deeplink = try? self.keeperCoreMainAssembly.deeplinkParser.parse(string: url.absoluteString) {
                            await MainActor.run {
                                self.didRequestDeeplinkHandling?(
                                    deeplink,
                                    UtmParameters(link: url.absoluteString)
                                )
                            }

                            return
                        }

                        let proofProvider = TonConnectNFTProofProvider(
                            wallet: self.wallet,
                            nft: self.nft,
                            mnemonicAccess: self.keeperCoreMainAssembly.secureAssembly.mnemonicAccess
                        )
                        let showServiceUnavailable = {
                            await MainActor.run {
                                let configuration = ToastPresenter.Configuration(title: TKLocales.Toast.serviceUnavailable)
                                ToastPresenter.showToast(configuration: configuration)
                            }
                        }
                        let composedUrl: URL?
                        do {
                            composedUrl = try await proofProvider.composeTonNFTProofURL(baseURL: url, passcode: passcode)
                        } catch {
                            Log.w("failed to get ton nft proof url due to error: \(error)")
                            return await showServiceUnavailable()
                        }
                        guard let composedUrl else {
                            Log.w("failed to get ton nft proof url - not found")
                            return await showServiceUnavailable()
                        }
                        await MainActor.run {
                            self.didOpenDapp?(composedUrl, nil)
                        }
                    }
                }
            )
        }

        module.output.didTapOpenInTonviewer = { [weak self] context in
            guard let self = self else {
                return
            }

            let linkBuilder = TonviewerURLBuilder(configuration: keeperCoreMainAssembly.configurationAssembly.configuration)
            guard let url = linkBuilder.buildURL(context: context, network: self.wallet.network) else {
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
                self.close()
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
                self.close()
            }
        }

        router.push(
            viewController: module.view,
            onPopClosures: { [weak self] in
                guard self?.presentationStyle == .pushed else { return }
                self?.didClose?()
            }
        )
    }

    func close() {
        switch presentationStyle {
        case .modal:
            didClose?()
        case .pushed:
            router.pop()
        }
    }

    func openTransfer(nft: NFT, recipient: LegacyRecipient? = nil) {
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
            sendInput: .direct(item: .ton(.nft(nft))),
            sendSource: .jettonScreen,
            recipient: recipient
        )

        sendTokenCoordinator.didFinish = { [weak self, weak navigationController] in
            guard let self else {
                return
            }
            self.sendTokenCoordinator = nil
            navigationController?.dismiss(animated: true)
            self.removeChild($0)
            self.didPerformTransaction?()
        }

        sendTokenCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.router.dismiss(animated: true) {
                self?.didRequestOpenBuySell?(isInternalPurchasing)
                self?.close()
            }
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

        let nftService = keeperCoreMainAssembly.servicesAssembly.nftService()
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
            .highlighted: .Accent.orange.withAlphaComponent(0.64),
        ]
        reportSpamButton.action = {
            [weak bottomSheetViewController, nft, weak nftManagmentStore, nftService, weak self] in
            bottomSheetViewController?.dismiss {
                Task {
                    let network = self?.wallet.network ?? .mainnet

                    let toastTitle: String
                    if nft.collection != nil {
                        toastTitle = TKLocales.Collectibles.collectionMarkedAsSpam
                    } else {
                        toastTitle = TKLocales.Collectibles.nftMarkedAsSpam
                    }

                    ToastPresenter.showToast(configuration: .loading)
                    try? await nftService.changeSuspiciousState(nft, network: network, isScam: true)

                    if let collection = nft.collection {
                        await nftManagmentStore?.spamItem(.collection(collection.address))
                    } else {
                        await nftManagmentStore?.spamItem(.singleItem(nft.address))
                    }

                    await MainActor.run {
                        ToastPresenter.hideAll()

                        let configuration = ToastPresenter.Configuration(title: toastTitle)
                        ToastPresenter.showToast(configuration: configuration)
                        self?.close()
                    }
                }
            }
        }

        var notSpamButton = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        notSpamButton.content = .init(title: .plainString(TKLocales.NftDetails.UnverifiedNft.notSpam))
        notSpamButton.action = { [weak bottomSheetViewController, nft, weak nftManagmentStore, nftService, weak self] in
            Task {
                bottomSheetViewController?.dismiss()

                let network = self?.wallet.network ?? .mainnet
                try? await nftService.changeSuspiciousState(nft, network: network, isScam: false)

                if let collection = nft.collection {
                    await nftManagmentStore?.approveItem(.collection(collection.address))
                } else {
                    await nftManagmentStore?.approveItem(.singleItem(nft.address))
                }
            }
        }

        let content = [
            TKLocales.NftDetails.UnverifiedNft.usedForSpamDescription,
            TKLocales.NftDetails.UnverifiedNft.usedForScamDescription,
            TKLocales.NftDetails.UnverifiedNft.littleInfoDescription,
        ]

        var buttons = [TKButton.Configuration]()
        if wallet.isReportSpamAvailable {
            buttons.append(reportSpamButton)
            if state != .approved {
                buttons.append(notSpamButton)
            }
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
        openDNSLink(wallet: wallet, nft: nft, flow: .link)
    }

    func openUnlinkDomain(wallet: Wallet, nft: NFT) {
        openDNSLink(wallet: wallet, nft: nft, flow: .unlink)
    }

    func openDNSLink(wallet: Wallet, nft: NFT, flow: LinkDNSCoordinator.Flow) {
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
            flow: flow
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didFinish = { [weak self] in
            guard let self else {
                return
            }
            self.router.dismiss()
            self.removeChild($0)
            self.close()
            self.didPerformTransaction?()
        }

        coordinator.didRequestDepositTon = { [weak self, weak coordinator] in
            guard let self else { return }
            if let coordinator {
                removeChild(coordinator)
            }
            didRequestDepositTon?()
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

        coordinator.didFinish = { [weak self] in
            guard let self else { return }
            self.router.dismiss()
            self.removeChild($0)
            self.didPerformTransaction?()
        }

        renewDNSCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()
    }
}

private extension FriendlyAddress {
    static var burnAddress: FriendlyAddress? = try? FriendlyAddress(string: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
}

private extension CollectiblesDetailsCoordinator.PresentationStyle {
    var navigationButton: NFTDetailsNavigationButton {
        switch self {
        case .modal:
            return .swipeDown
        case .pushed:
            return .back
        }
    }
}
