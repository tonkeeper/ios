import Foundation
import KeeperCore
import os
import TKCore

struct DappAssembly {
    private init() {}
    static func module(
        dapp: Dapp,
        analyticsSession: DappOpenAnalyticsSession,
        deeplinkHandler: @escaping ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void),
        deeplinkParser: DeeplinkParser,
        messageHandler: DappMessageHandler,
        wallet: Wallet?,
        explorerURLMatcher: BlockchainExplorerURLMatcher
    )
        -> MVVMModule<DappViewController, DappModuleOutput, DappModuleInput>
    {
        let logger = Logger(subsystem: "com.tonkeeper.dapps", category: "dApps")
        let viewModel = DappViewModelImplementation(
            dapp: dapp,
            analyticsSession: analyticsSession,
            messageHandler: messageHandler,
            wallet: wallet,
            explorerURLMatcher: explorerURLMatcher
        )

        let viewController = DappViewController(
            viewModel: viewModel,
            logger: logger,
            deeplinkHandler: deeplinkHandler,
            deeplinkParser: deeplinkParser
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
