import TKCoordinator
import TKCore
import TKUIKit

final class PriceImpactCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private weak var bottomSheetViewController: TKBottomSheetViewController?

    func start(presentation: PriceImpactPresentation) {
        let viewController = TKBottomSheetHostingController(
            content: PriceImpactView(
                presentation: PriceImpactPresentation(
                    style: presentation.style,
                    title: presentation.title,
                    subtitle: presentation.subtitle,
                    description: presentation.description,
                    confirmButtonTitle: presentation.confirmButtonTitle,
                    backButtonTitle: presentation.backButtonTitle,
                    // The actions run in the dismiss completion: acting while the sheet is
                    // still animating out makes the next modal (e.g. the passcode screen)
                    // present from the dismissing controller and get torn down with it.
                    didTapClose: { [weak self] in
                        self?.dismiss(completion: presentation.didTapClose)
                    },
                    didTapConfirm: { [weak self] in
                        self?.dismiss(completion: presentation.didTapConfirm)
                    },
                    didTapBack: { [weak self] in
                        self?.dismiss(completion: presentation.didTapBack)
                    }
                )
            ),
            headerConfiguration: .popup
        )
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: viewController,
            ignoreBottomSafeArea: true
        )
        bottomSheetViewController.didClose = { _ in
            presentation.didTapClose()
        }
        self.bottomSheetViewController = bottomSheetViewController
        bottomSheetViewController.present(
            fromViewController: router.rootViewController.topPresentedViewController()
        )
    }
}

private extension PriceImpactCoordinator {
    func dismiss(completion: (() -> Void)? = nil) {
        guard let bottomSheetViewController else {
            completion?()
            return
        }
        bottomSheetViewController.dismiss(completion: completion)
    }
}
