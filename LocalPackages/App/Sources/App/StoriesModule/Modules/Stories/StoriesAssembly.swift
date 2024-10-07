import Foundation
import TKCore
import KeeperCore

struct StoriesAssembly {
  private init() {}
  static func module(storiesController: StoriesController) -> MVVMModule<StoriesViewController, StoriesModuleOutput, Void> {
    let viewModel = StoriesViewModelImplementation(
      storiesController: storiesController
    )
    let viewController = StoriesViewController(viewModel: viewModel)
    return MVVMModule(view: viewController, output: viewModel, input: Void())
  }
}
