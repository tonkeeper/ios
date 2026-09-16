import TKCoordinator
import TKCore
import TKUIKit

final class NetworkFeePickerCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private weak var bottomSheetViewController: TKBottomSheetViewController?
    private var isSelectingItem = false

    func start(
        presentation: NetworkFeePickerPresentation
    ) {
        isSelectingItem = false
        let module = makeModule(
            presentation: presentation
        )
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view
        )
        self.bottomSheetViewController = bottomSheetViewController

        module.output.didSelectItem = { [weak self, presentation, weak bottomSheetViewController] item, category in
            guard !item.isDisabled || item.actionTitle != nil,
                  let self,
                  !self.isSelectingItem
            else {
                return
            }
            self.isSelectingItem = true
            guard let bottomSheetViewController else {
                self.isSelectingItem = false
                presentation.didSelectItem(item, category)
                return
            }
            bottomSheetViewController.dismiss { [weak self] in
                self?.isSelectingItem = false
                presentation.didSelectItem(item, category)
            }
        }
        module.output.didRequestClose = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(
            fromViewController: router.rootViewController.topPresentedViewController()
        )
    }

    private func makeModule(
        presentation: NetworkFeePickerPresentation
    ) -> MVVMModule<NetworkFeePickerViewController, NetworkFeePickerModuleOutput, NetworkFeePickerModuleInput> {
        let viewModel = NetworkFeePickerViewModelImplementation(
            configuration: presentation.configuration,
            dataSource: presentation.dataSource
        )
        let viewController = NetworkFeePickerViewController(viewModel: viewModel)
        return .init(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}
