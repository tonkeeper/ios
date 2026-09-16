import Foundation
import KeeperCore
import TKCore

struct BatteryWebAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        url: URL,
        title: String,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<BatteryWebViewController, Void, Void> {
        let viewModel = BatteryWebViewModelImplementation(
            wallet: wallet,
            url: url,
            title: title,
            authorizationService: keeperCoreMainAssembly.batteryAssembly.batteryWebAuthorizationService()
        )
        let viewController = BatteryWebViewController(viewModel: viewModel)
        return .init(view: viewController, output: (), input: ())
    }
}
