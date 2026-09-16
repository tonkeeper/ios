import Foundation
import KeeperCore
import TKCore

struct AddWalletOptionPickerAssembly {
    private init() {}

    @MainActor
    static func module(
        options: [AddWalletOption],
        multichainImportChains: [MultichainChain]
    ) -> MVVMModule<AddWalletOptionPickerViewController, AddWalletOptionPickerModuleOutput, Void> {
        let viewModel = AddWalletOptionPickerViewModelImplementation(
            options: options,
            multichainImportChains: multichainImportChains
        )
        let viewController = AddWalletOptionPickerViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
