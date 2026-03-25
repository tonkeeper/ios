import Foundation
import TKCore

struct RampPickerAssembly {
    private init() {}

    static func module(model: RampPickerModel, flow: RampFlow) -> MVVMModule<RampPickerViewController, RampPickerModuleOutput, Void> {
        let viewModel = RampPickerViewModelImplementation(pickerModel: model, flow: flow)
        let viewController = RampPickerViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
