import Foundation
import KeeperCore
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
        isSignMessageSupported: Bool,
        explorerURLMatcher: BlockchainExplorerURLMatcher,
        earnFeaturedVaultsRepository: EarnFeaturedVaultsRepository,
        userAgent: String
    )
        -> MVVMModule<DappViewController, DappModuleOutput, DappModuleInput>
    {
        let viewModel = DappViewModelImplementation(
            dapp: dapp,
            analyticsSession: analyticsSession,
            messageHandler: messageHandler,
            wallet: wallet,
            isSignMessageSupported: isSignMessageSupported,
            explorerURLMatcher: explorerURLMatcher,
            earnFeaturedVaultsRepository: earnFeaturedVaultsRepository,
            userAgent: userAgent
        )

        let viewController = DappViewController(
            viewModel: viewModel,
            deeplinkHandler: deeplinkHandler,
            deeplinkParser: deeplinkParser
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
