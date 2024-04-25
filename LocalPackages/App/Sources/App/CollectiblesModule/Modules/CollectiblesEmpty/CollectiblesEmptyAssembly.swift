import Foundation
import TKCore

struct CollectiblesEmptyAssembly {
  private init() {}
  static func module() -> MVVMModule<CollectiblesEmptyViewController, CollectiblesEmptyModuleOutput, Void> {
    let viewModel = CollectiblesEmptyViewModelImplementation()
    let viewController = CollectiblesEmptyViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
