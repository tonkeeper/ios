import Foundation
import TKCore

struct AddWalletOptionPickerAssembly {
  private init() {}
  static func module(options: [AddWalletOption]) -> MVVMModule<AddWalletOptionPickerViewController, AddWalletOptionPickerModuleOutput, Void> {
    let viewModel = AddWalletOptionPickerViewModelImplementation(options: options)
    let viewController = AddWalletOptionPickerViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
