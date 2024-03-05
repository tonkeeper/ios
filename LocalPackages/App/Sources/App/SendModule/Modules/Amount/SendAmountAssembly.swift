import Foundation
import TKCore
import KeeperCore

struct SendAmountAssembly {
  private init() {}
  static func module(sendAmountController: SendAmountController) -> MVVMModule<SendAmountViewController, SendAmountModuleOutput, SendAmountModuleInput> {
    let viewModel = SendAmountViewModelImplementation(sendAmountController: sendAmountController)
    let viewController = SendAmountViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
