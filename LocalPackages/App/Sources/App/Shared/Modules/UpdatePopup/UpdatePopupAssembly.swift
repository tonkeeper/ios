import UIKit
import TKUIKit
import TKCore
import KeeperCore

struct UpdatePopupAssembly {
  private init() {}
  static func module() -> MVVMModule<TKBottomSheetViewController, UpdatePopupModuleOutput, UpdatePopupModuleInput> {
    let viewModel = UpdatePopupViewModelImplementation()
    let viewController = UpdatePopupViewController(viewModel: viewModel)
    return .init(
      view: TKBottomSheetViewController(contentViewController: viewController),
      output: viewModel,
      input: viewModel
    )
  }
}
