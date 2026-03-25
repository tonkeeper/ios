import Foundation
import KeeperCore
import TKCore
import UIKit

struct ProviderPickerAssembly {
    private init() {}

    static func module(items: [ProviderPickerItem]) -> MVVMModule<ProviderPickerViewController, ProviderPickerModuleOutput, Void> {
        let viewModel = ProviderPickerViewModel(items: items)
        let viewController = ProviderPickerViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}
