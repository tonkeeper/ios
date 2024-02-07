import Foundation
import TKCore

struct CollectiblesAssembly {
  private init() {}
  static func module() -> MVVMModule<CollectiblesViewController, CollectiblesViewModel, Void> {
    let viewModel = CollectiblesViewModelImplementation()
    let viewController = CollectiblesViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
