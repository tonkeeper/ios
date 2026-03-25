import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import UIKit

public final class BuyCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didOpenItem: ((URL, _ fromViewController: UIViewController) -> Void)?
    var didClose: (() -> Void)?

    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: ViewControllerRouter
    ) {
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override public func start() {
        openBuySellList()
    }
}

private extension BuyCoordinator {
    func openBuySellList() {
        let module = BuySellListAssembly.module(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.didSelectURL = { [weak self, weak bottomSheetViewController] url in
            guard let bottomSheetViewController else { return }
            self?.didOpenItem?(url, bottomSheetViewController)
        }

        module.output.didSelectItem = { [weak self, weak bottomSheetViewController] item, openClosure in
            guard let bottomSheetViewController else { return }
            self?.openWarning(
                item: item,
                fromViewController: bottomSheetViewController,
                openClosure: openClosure
            )
        }

        bottomSheetViewController.didClose = { [weak self] _ in
            self?.didClose?()
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func openWarning(
        item: BuySellItem,
        fromViewController: UIViewController,
        openClosure: @escaping () -> Void
    ) {
        let module = BuyListPopUpAssembly.module(
            buySellItemModel: item,
            appSettings: coreAssembly.appSettings,
            urlOpener: coreAssembly.urlOpener()
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        bottomSheetViewController.present(fromViewController: fromViewController)

        module.output.didTapOpen = { [weak self, weak bottomSheetViewController] item in
            guard let bottomSheetViewController else { return }
            bottomSheetViewController.dismiss {
                self?.didOpenItem?(item.actionUrl, fromViewController)
                openClosure()
            }
        }
    }
}
