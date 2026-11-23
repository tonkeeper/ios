import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKUIKit
import UIKit

/// Tops up what a deposit's fee method spends, the way a swap's fee picker does: the battery, or
/// the wallet's asset through its receive screen.
@MainActor
struct PerpsFeeRefill {
    let wallet: Wallet
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly

    /// `assetId` `nil` is the battery. `onEnd` reports whether the method may have been topped up;
    /// the coordinator returned is held until then.
    func start(assetId: String?, from presenter: UIViewController, onEnd: @escaping @MainActor (_ refilled: Bool) -> Void) -> Coordinator? {
        let router = ViewControllerRouter(rootViewController: presenter)
        guard let assetId else { return battery(router: router, onEnd: onEnd) }
        return receive(assetId: assetId, router: router, onEnd: onEnd)
    }

    private func battery(router: ViewControllerRouter, onEnd: @escaping @MainActor (Bool) -> Void) -> Coordinator {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        let coordinator = BatteryRefillCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            jettonMasterAddress: nil,
            initiatedBy: .user,
            analyticsSource: .insufficientFunds,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        coordinator.didRechargeSuccess = { [weak navigationController] in
            navigationController?.dismiss(animated: true) { onEnd(true) }
        }
        // Holds the router, which reports a swipe-down through `onDismiss`.
        coordinator.didFinish = { [router, weak navigationController] _ in
            withExtendedLifetime(router) {}
            navigationController?.dismiss(animated: true)
            onEnd(false)
        }
        coordinator.start(deeplink: nil)
        router.presentOverTopPresented(
            navigationController,
            completion: { [weak coordinator] in coordinator?.didAppear() },
            onDismiss: { onEnd(false) }
        )
        return coordinator
    }

    private func receive(assetId: String, router: ViewControllerRouter, onEnd: @escaping @MainActor (Bool) -> Void) -> Coordinator? {
        guard let state = wallet.multichainWalletState,
              let chain = MultichainChain(assetId: assetId),
              let address = state.walletAddress(for: chain, preferredType: wallet.preferredMultichainAddressType(for: chain))
        else {
            Log.perps.w("Deposit fee refill skipped: no receive address assetId=\(assetId)")
            return nil
        }
        let coordinator = ReceiveModule(
            dependencies: .init(coreAssembly: coreAssembly, keeperCoreMainAssembly: keeperCoreMainAssembly)
        ).createReceiveCoordinator(router: router, wallet: wallet, address: ReceiveAddressPreview(address: address))
        coordinator.didClose = { onEnd(true) }
        coordinator.start()
        return coordinator
    }
}
