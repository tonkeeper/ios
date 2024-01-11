import Foundation
import TKCore

struct HistoryAssembly {
  private init() {}
  static func module() -> MVVMModule<HistoryViewController, HistoryViewModel, Void> {
    let viewModel = HistoryViewModelImplementation()
    let viewController = HistoryViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
