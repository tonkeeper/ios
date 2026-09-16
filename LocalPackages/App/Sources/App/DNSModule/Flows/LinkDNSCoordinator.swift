import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import UIKit

final class LinkDNSCoordinator: RouterCoordinator<WindowRouter> {
    enum Flow {
        case link
        case unlink
    }

    var didCancel: (() -> Void)?
    var didRequestDepositTon: (() -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let wallet: Wallet
    private let flow: Flow
    private let linkDNSController: LinkDNSController
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        router: WindowRouter,
        wallet: Wallet,
        flow: Flow,
        linkDNSController: LinkDNSController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.wallet = wallet
        self.flow = flow
        self.linkDNSController = linkDNSController
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil
        return true
    }

    override func start() {
        ToastPresenter.showToast(configuration: .loading)
        Task {
            do {
                let dnsLink: DNSLink
                switch flow {
                case .link:
                    dnsLink = try .link(address: .friendly(wallet.friendlyAddress))
                case .unlink:
                    dnsLink = .unlink
                }
                let emulation = try await linkDNSController.emulate(dnsLink: dnsLink)
                await MainActor.run {
                    ToastPresenter.hideAll()
                    switch emulation {
                    case let .confirmation(model):
                        openConfirmation(model: model, dnsLink: dnsLink)
                    case let .insufficientFunds(required, available):
                        openInsufficientFunds(required: required, available: available)
                    }
                }
            } catch {
                Log.w("failed to emulate dns link due to error: \(error)")
                await MainActor.run {
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(configuration: .failed)
                    didCancel?()
                }
            }
        }
    }

    override func didMoveTo(toParent parent: (any Coordinator)?) {
        if parent == nil {
            walletTransferSignCoordinator?.externalSignHandler?(nil)
        }
    }
}

private extension LinkDNSCoordinator {
    func openInsufficientFunds(required: BigUInt, available: BigUInt) {
        let rootViewController = UIViewController()
        router.window.rootViewController = rootViewController
        router.window.makeKeyAndVisible()

        let (requiredText, availableText) = keeperCoreMainAssembly.formattersAssembly.amountFormatter
            .formatDistinctly(
                required,
                available,
                fractionDigits: TonInfo.fractionDigits,
                accessory: .tokenSymbol(TonInfo.symbol)
            )

        let walletTitle = InsufficientFeePopupContent.walletTitle(for: wallet)
        let content = InsufficientFeePopupContent(
            title: TKLocales.InsufficientFunds.Wallet.title(walletTitle.argument),
            caption: TKLocales.InsufficientFunds.toBePaidYourBalance(
                requiredText,
                availableText
            ),
            primaryButtonTitle: TKLocales.InsufficientFunds.buyTokenTitle(TonInfo.symbol),
            walletIcon: walletTitle.icon,
            walletName: walletTitle.name,
            walletNamePlaceholder: walletTitle.namePlaceholder
        )

        var didHandleAction = false
        let sheetViewController = PopupContentPresenter.presentInsufficientFee(
            content: content,
            from: rootViewController,
            onPrimary: { [didRequestDepositTon] in
                guard !didHandleAction else { return }
                didHandleAction = true
                didRequestDepositTon?()
            }
        )

        sheetViewController.didClose = { [weak self] isInteractivly in
            guard isInteractivly, !didHandleAction else { return }
            didHandleAction = true
            self?.didCancel?()
        }
    }

    func openConfirmation(model: SendTransactionModel, dnsLink: DNSLink) {
        let rootViewController = UIViewController()
        router.window.rootViewController = rootViewController
        router.window.makeKeyAndVisible()

        let module = LinkDNSAssembly.module(
            model: model,
            dnsLink: dnsLink,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        bottomSheetViewController.didClose = { [weak self] _ in
            self?.didCancel?()
        }

        module.output.didCancel = { [weak self, weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss(completion: {
                self?.didCancel?()
            })
        }

        module.output.didTapConfirmButton = { [weak self, weak bottomSheetViewController] dnsLink in
            guard let self, let bottomSheetViewController else { return false }
            return await self.performLink(
                fromViewController: bottomSheetViewController,
                dnsLink: dnsLink
            )
        }

        module.output.didLink = { [weak self, weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss(completion: {
                self?.didFinish?(self)
            })
        }

        bottomSheetViewController.present(fromViewController: rootViewController)
    }

    func performLink(fromViewController: UIViewController, dnsLink: DNSLink) async -> Bool {
        do {
            let signClosure = { [weak self, wallet] transferData async throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                let coordinator = WalletTransferSignCoordinator(
                    router: ViewControllerRouter(rootViewController: fromViewController),
                    wallet: wallet,
                    transferData: transferData,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly
                )

                self.walletTransferSignCoordinator = coordinator

                return try await coordinator
                    .handleSign(parentCoordinator: self)
                    .get()
            }
            try await linkDNSController.sendLinkTransaction(dnsLink: dnsLink, signClosure: signClosure)
            return true
        } catch {
            return false
        }
    }
}
