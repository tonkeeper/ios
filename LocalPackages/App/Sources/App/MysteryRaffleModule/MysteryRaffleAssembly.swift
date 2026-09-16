import Foundation
import TKCore

struct MysteryRaffleAssembly {
    private init() {}

    @MainActor
    static func module(
        content: MysteryRaffleContent?
    )
        -> MVVMModule<MysteryRaffleHostingViewController, MysteryRaffleModuleOutput, MysteryRaffleViewModel>
    {
        let viewModel = MysteryRaffleViewModel(content: content)
        let viewController = MysteryRaffleHostingViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}
