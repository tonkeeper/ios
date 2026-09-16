import Foundation
import KeeperCore
import UIKit

extension MainCoordinator {
    /// The battery page authenticates a multichain wallet through its own bridge, so it does not
    /// go through the TonConnect dApp browser.
    func openBatteryWeb(wallet: Wallet, url: URL, title: String) {
        let module = BatteryWebAssembly.module(
            wallet: wallet,
            url: url,
            title: title,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        module.view.modalPresentationStyle = .fullScreen
        router.rootViewController.modalPresentationSourceViewController().present(module.view, animated: true)
    }
}
