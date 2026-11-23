import AppUI
import KeeperCore
import TKUIKit
import UIKit

extension MainCoordinator {
    func makeSwapStatusTracker() -> MultichainSwapStatusTracker {
        let multichainService = keeperCoreMainAssembly.servicesAssembly.multichainService()
        let tracker = MultichainSwapStatusTracker(
            loadActivities: { state in
                try await multichainService.getWalletActivities(
                    state: state,
                    limit: 50,
                    cursor: nil,
                    chain: nil,
                    assetId: nil,
                    activityTypeFilter: nil,
                    showPerps: false,
                    market: nil,
                    hideDust: nil
                ).activities
            },
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        tracker.onOpenDetails = { [weak self] in
            self?.openSwapDetails()
        }
        keeperCoreMainAssembly.multichainAssembly.realtimeManager.addHistoryInvalidationObserver(tracker) { tracker, walletId in
            Task { @MainActor in
                tracker.historyDidChange(multichainWalletId: walletId)
            }
        }
        return tracker
    }

    func openSwapDetails() {
        guard let trackedSwap = swapStatusTracker.trackedSwap else { return }
        let dateFormatter = keeperCoreMainAssembly.formattersAssembly.dateFormatter
        dateFormatter.dateFormat = "d MMM yyyy, HH:mm"
        let viewModel = MultichainSwapDetailsViewModel(
            tracker: swapStatusTracker,
            trackedSwap: trackedSwap,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: dateFormatter
        )
        weak var presentedViewController: UIViewController?
        let viewController = TKHostingController(
            content: MultichainSwapDetailsViewContainer(
                viewModel: viewModel,
                onClose: {
                    presentedViewController?.dismiss(animated: true)
                },
                onOpenTransaction: { [weak self] url, title in
                    self?.openDapp(title: title, url: url, analyticsFrom: .history)
                },
                onCopyTransactionHash: { hash in
                    Pasteboard.copy(value: hash)
                }
            )
        )
        viewController.view.backgroundColor = .Background.page
        presentedViewController = viewController
        router.rootViewController.topPresentedViewController().present(viewController.tkLiquidGlassModal(), animated: true)
    }
}
