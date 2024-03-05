import Foundation
import TKCore
import KeeperCore

struct SendRecipientAssembly {
  private init() {}
  static func module(sendRecipientController: SendRecipientController) -> MVVMModule<SendRecipientViewController, SendRecipientModuleOutput, SendRecipientModuleInput> {
    let viewModel = SendRecipientViewModelImplementation(sendRecipientController: sendRecipientController)
    let viewController = SendRecipientViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
