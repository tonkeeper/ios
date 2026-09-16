import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class MainHistoryCoordinatorFactory {
    struct Output {
        let didOpenTonEventDetails: (Wallet, AccountEventDetailsEvent, Network, UIViewController?) -> Void
        let didOpenTronEventDetails: (Wallet, TronTransaction, Network, UIViewController?) -> Void
        let didDecryptComment: (Wallet, EncryptedCommentPayload, String) -> Void
        let didOpenDapp: (URL, String?) -> Void
        let didTapAddFunds: (Wallet) -> Void
        let didRequestDepositTon: (Wallet) -> Void
    }

    private let historyModule: HistoryModule
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let output: Output

    init(
        historyModule: HistoryModule,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        output: Output
    ) {
        self.historyModule = historyModule
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.output = output
    }

    func makeCoordinator(
        wallet: Wallet,
        router: NavigationControllerRouter? = nil,
        presentationStyle: HistoryPresentationStyle,
        fromViewController: UIViewController?
    ) -> RouterCoordinator<NavigationControllerRouter> {
        if let multichainState = multichainHistoryState(for: wallet) {
            return makeMultichainCoordinator(
                wallet: wallet,
                multichainState: multichainState,
                router: router ?? Self.makeDefaultRouter(),
                presentationStyle: presentationStyle
            )
        }

        return makeLegacyCoordinator(
            router: router,
            presentationStyle: presentationStyle,
            fromViewController: fromViewController
        )
    }

    static func makeDefaultRouter() -> NavigationControllerRouter {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        navigationController.setNavigationBarHidden(true, animated: false)
        return NavigationControllerRouter(rootViewController: navigationController)
    }
}

private extension MainHistoryCoordinatorFactory {
    func makeLegacyCoordinator(
        router: NavigationControllerRouter?,
        presentationStyle: HistoryPresentationStyle,
        fromViewController: UIViewController?
    ) -> RouterCoordinator<NavigationControllerRouter> {
        let historyCoordinator = historyModule.createHistoryCoordinator(
            routerOrNil: router,
            presentationStyle: presentationStyle
        )
        historyCoordinator.didOpenTonEventDetails = { [output] wallet, event, network in
            output.didOpenTonEventDetails(
                wallet,
                event,
                network,
                fromViewController
            )
        }
        historyCoordinator.didOpenTronEventDetails = { [output] wallet, event, network in
            output.didOpenTronEventDetails(
                wallet,
                event,
                network,
                fromViewController
            )
        }
        historyCoordinator.didDecryptComment = { [output] wallet, payload, eventId in
            output.didDecryptComment(wallet, payload, eventId)
        }
        historyCoordinator.didOpenDapp = { [output] url, title in
            output.didOpenDapp(url, title)
        }
        historyCoordinator.didTapAddFunds = { [output] wallet in
            output.didTapAddFunds(wallet)
        }
        historyCoordinator.didRequestDepositTon = { [output] wallet in
            output.didRequestDepositTon(wallet)
        }

        return historyCoordinator
    }

    func makeMultichainCoordinator(
        wallet: Wallet,
        multichainState: MultichainWalletState,
        router: NavigationControllerRouter,
        presentationStyle: HistoryPresentationStyle
    ) -> RouterCoordinator<NavigationControllerRouter> {
        return MultichainHistoryCoordinator(
            router: router,
            wallet: wallet,
            multichainState: multichainState,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentationStyle: presentationStyle,
            didTapAddFunds: { [output] in
                output.didTapAddFunds(wallet)
            },
            onOpenTransaction: { [output] url, title in
                output.didOpenDapp(url, title)
            }
        )
    }

    func multichainHistoryState(for wallet: Wallet) -> MultichainWalletState? {
        wallet.multichainWalletState
    }
}
