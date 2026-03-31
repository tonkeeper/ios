import Foundation
import KeeperCore
import os
import TKCore

struct DappAssembly {
    private init() {}
    static func module(
        dapp: Dapp,
        analyticsProvider: AnalyticsProvider,
        deeplinkHandler: @escaping ((_ deeplink: Deeplink) -> Void),
        messageHandler: DappMessageHandler,
        wallet: Wallet?
    )
        -> MVVMModule<DappViewController, DappModuleOutput, DappModuleInput>
    {
        let logger = Logger(subsystem: "com.tonkeeper.dapps", category: "dApps")
        let viewModel = DappViewModelImplementation(
            dapp: dapp,
            messageHandler: messageHandler,
            wallet: wallet,
            analyticsProvider: analyticsProvider
        )

        let viewController = DappViewController(
            viewModel: viewModel,
            logger: logger,
            deeplinkHandler: deeplinkHandler
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
