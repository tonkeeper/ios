import Foundation
import TKCore
import KeeperCore

struct SwapTokenPickerAssembly {
  private init() {}
  static func module(swapTokenPickerController: SwapTokenPickerController) -> MVVMModule<SwapTokenPickerViewController, SwapTokenPickerModuleOutput, Void> {
    let viewModel = SwapTokenPickerViewModelImplementation(swapTokenPickerController: swapTokenPickerController)
    let viewController = SwapTokenPickerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
