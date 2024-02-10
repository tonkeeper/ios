import Foundation
import TKCore

struct HistoryEmptyAssembly {
  private init() {}
  static func module() -> MVVMModule<HistoryEmptyViewController, HistoryEmptyModuleOutput, Void> {
    let viewModel = HistoryEmptyViewModelImplementation()
    let viewController = HistoryEmptyViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
