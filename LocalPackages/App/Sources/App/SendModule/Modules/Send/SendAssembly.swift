import Foundation
import TKCore
import KeeperCore

struct SendAssembly {
  private init() {}
  static func module(sendController: SendController) -> MVVMModule<SendViewController, SendModuleOutput, SendModuleInput> {
    let viewModel = SendViewModelImplementation(sendController: sendController)
    let viewController = SendViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
