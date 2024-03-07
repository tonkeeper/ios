import Foundation
import TKCore
import KeeperCore

struct TokenPickerAssembly {
  private init() {}
  static func module(tokenPickerController: TokenPickerController) -> MVVMModule<TokenPickerViewController, TokenPickerModuleOutput, Void> {
    let viewModel = TokenPickerViewModelImplementation(tokenPickerController: tokenPickerController)
    let viewController = TokenPickerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
