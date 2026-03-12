import Foundation
import KeeperCore
import TKCore

struct SendConfirmationAssembly {
    private init() {}
    static func module(sendConfirmationController: SendConfirmationController) -> MVVMModule<SendConfirmationViewController, SendConfirmationModuleOutput, SendConfirmationModuleInput> {
        let viewModel = SendConfirmationViewModelImplementation(sendConfirmationController: sendConfirmationController)
        let viewController = SendConfirmationViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
