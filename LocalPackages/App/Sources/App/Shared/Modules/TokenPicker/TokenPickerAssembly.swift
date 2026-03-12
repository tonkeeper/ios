import Foundation
import KeeperCore
import TKCore

struct TokenPickerAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        model: TokenPickerModel,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<TokenPickerViewController, TokenPickerModuleOutput, Void> {
        let viewModel = TokenPickerViewModelImplementation(
            tokenPickerModel: model,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )
        let viewController = TokenPickerViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
