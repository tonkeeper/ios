
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
        analyticsProvider: AnalyticsProvider,
        deeplinkHandler: @escaping ((_ deeplink: Deeplink) -> Void),
        messageHandler: DappMessageHandler,
        wallet: Wallet?,
        walletKit: TONWalletKit,
        eventsHandler: any TONBridgeEventsHandler
    )
        -> MVVMModule<DappViewController, DappModuleOutput, DappModuleInput>
    {
        let viewModel = DappWalletKitViewModel(
            dapp: dapp,
            messageHandler: messageHandler,
            wallet: wallet,
            analyticsProvider: analyticsProvider,
            walletKit: walletKit,
            eventsHandler: eventsHandler
        )

        let logger = Logger(subsystem: "com.tonkeeper.dapps", category: "dApps")

        let viewController = DappViewController(
            viewModel: viewModel,
            logger: logger,
            deeplinkHandler: deeplinkHandler
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
