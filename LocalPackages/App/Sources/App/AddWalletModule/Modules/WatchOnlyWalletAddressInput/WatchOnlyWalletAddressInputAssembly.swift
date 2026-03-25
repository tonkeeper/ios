import Foundation
import KeeperCore
import TKCore
import UIKit

struct WatchOnlyWalletAddressInputAssembly {
    private init() {}
    static func module(controller: WatchOnlyWalletAddressInputController) -> MVVMModule<UIViewController, WatchOnlyWalletAddressInputModuleOutput, Void> {
        let viewModel = WatchOnlyWalletAddressInputViewModelImplementation(controller: controller)
        let viewController = WatchOnlyWalletAddressInputViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
