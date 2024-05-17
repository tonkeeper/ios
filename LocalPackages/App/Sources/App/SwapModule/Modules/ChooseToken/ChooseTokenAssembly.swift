import Foundation
import TKCore
import KeeperCore

struct ChooseTokenAssembly {
  private init() {}
  static func module() -> MVVMModule<ChooseTokenViewController, ChooseTokenModuleOutput, Void> {
    let viewModel = ChooseTokenViewModelImplementation()
    let viewController = ChooseTokenViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}

