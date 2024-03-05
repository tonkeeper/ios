import Foundation
import TKCore
import KeeperCore

struct SendCommentAssembly {
  private init() {}
  static func module(sendCommentController: SendCommentController) -> MVVMModule<SendCommentViewController, SendCommentModuleOutput, SendCommentModuleInput> {
    let viewModel = SendCommentViewModelImplementation(sendCommentController: sendCommentController)
    let viewController = SendCommentViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
