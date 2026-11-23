import TKCoordinator
import TKCore
import TKUIKit

/// Only presents a sheet, so it takes a `ViewControllerRouter`: a `NavigationControllerRouter`
/// made for it would take over its navigation controller's delegate from the flow that owns it.
final class NetworkFeePickerCoordinator: RouterCoordinator<ViewControllerRouter> {
    private var isSelectingItem = false

    convenience init(router: NavigationControllerRouter) {
        self.init(router: ViewControllerRouter(rootViewController: router.rootViewController))
    }

    /// `didFinish` comes once the picker is gone, after the pick it was closed with.
    func start(
        presentation: NetworkFeePickerPresentation,
        didFinish: (() -> Void)? = nil
    ) {
        isSelectingItem = false
        let module = makeModule(
            presentation: presentation
        )
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view
        )
        module.output.didSelectItem = { [weak self, presentation, weak bottomSheetViewController] item, category in
            // A row tapped while the sheet slides out after a close would never get its pick through.
            guard !item.isDisabled || item.actionTitle != nil,
                  let self,
                  !self.isSelectingItem,
                  bottomSheetViewController?.isDismissing != true
            else {
                return
            }
            self.isSelectingItem = true
            guard let bottomSheetViewController else {
                self.isSelectingItem = false
                presentation.didSelectItem(item, category)
                didFinish?()
                return
            }
            bottomSheetViewController.dismiss { [weak self] in
                self?.isSelectingItem = false
                presentation.didSelectItem(item, category)
                didFinish?()
            }
        }
        module.output.didRequestClose = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        // The sheet reports its dismissal before the dismissal's completion, where a pick is made.
        bottomSheetViewController.didDismiss = { [weak self] in
            guard self?.isSelectingItem != true else { return }
            didFinish?()
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
