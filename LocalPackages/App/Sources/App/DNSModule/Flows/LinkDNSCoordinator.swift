import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import TonSwift
import UIKit

final class LinkDNSCoordinator: RouterCoordinator<WindowRouter> {
    enum Flow {
        case link
        case unlink
    }

    var didCancel: (() -> Void)?

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
                let model = try await linkDNSController.emulate(dnsLink: dnsLink)
                await MainActor.run {
                    ToastPresenter.hideAll()
                    openConfirmation(model: model, dnsLink: dnsLink)
                }
            } catch {
                await MainActor.run {
                    ToastPresenter.hideAll()
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
