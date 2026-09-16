
import Foundation
import KeeperCore
import os
import TKCore
import TKFeatureFlags
import TONWalletKit

struct DappWalletKitAssembly {
    private init() {}
    static func module(
        dapp: Dapp,
        analyticsSession: DappOpenAnalyticsSession,
        deeplinkHandler: @escaping ((_ deeplink: Deeplink) -> Void),
        deeplinkParser: DeeplinkParser,
        messageHandler: DappMessageHandler,
        wallet: Wallet?,
        walletKit: TONWalletKit,
        eventsHandler: any TONBridgeEventsHandler,
        explorerURLMatcher: BlockchainExplorerURLMatcher
    )
        -> MVVMModule<DappViewController, DappModuleOutput, DappModuleInput>
    {
        let viewModel = DappWalletKitViewModel(
            dapp: dapp,
            analyticsSession: analyticsSession,
            messageHandler: messageHandler,
            wallet: wallet,
            walletKit: walletKit,
            eventsHandler: eventsHandler,
            explorerURLMatcher: explorerURLMatcher
        )

        let logger = Logger(subsystem: "com.tonkeeper.dapps", category: "dApps")

        let viewController = DappViewController(
            viewModel: viewModel,
            logger: logger,
            deeplinkHandler: deeplinkHandler,
            deeplinkParser: deeplinkParser
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
