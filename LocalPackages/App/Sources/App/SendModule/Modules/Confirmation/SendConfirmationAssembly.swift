import Foundation
import TKCore
import KeeperCore

struct SendConfirmationAssembly {
  private init() {}
  static func module(sendConfirmationController: SendConfirmationController) -> MVVMModule<SendConfirmationViewController, SendConfirmationModuleOutput, SendConfirmationModuleInput> {
    let viewModel = SendConfirmationViewModelImplementation(sendConfirmationController: sendConfirmationController)
    let viewController = SendConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
