import Foundation
import TKCore
import KeeperCore

struct LedgerConfirmAssembly {
  private init() {}
  static func module(coreAssembly: TKCore.CoreAssembly) -> MVVMModule<LedgerConfirmViewController, LedgerConfirmModuleOutput, Void> {
    let viewModel = LedgerConfirmViewModelImplementation()
    let viewController = LedgerConfirmViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
