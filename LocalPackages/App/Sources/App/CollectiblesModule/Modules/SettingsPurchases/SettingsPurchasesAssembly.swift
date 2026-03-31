import Foundation
import KeeperCore
import TKCore

enum SettingsPurchasesMode {
    case all
    case spam
}

struct SettingsPurchasesAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        mode: SettingsPurchasesMode,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<SettingsPurchasesViewController, SettingsPurchasesModuleOutput, Void>
    {
        let updateQueue = DispatchQueue(label: "SettingsPurchasesUpdateQueue")

        let viewModel = SettingsPurchasesViewModelImplementation(
            model: SettingsPurchasesModel(
                wallet: wallet,
                walletNFTStore: keeperCoreMainAssembly.storesAssembly.walletNFTsStore(wallet: wallet, nftService: keeperCoreMainAssembly.servicesAssembly.accountNftService()),
                accountNFTsManagementStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
                updateQueue: updateQueue
            ),
            mode: mode,
            wallet: wallet,
            tonviewerURLBuilder: TonviewerURLBuilder(configuration: keeperCoreMainAssembly.configurationAssembly.configuration)
        )

        let viewController = SettingsPurchasesViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
