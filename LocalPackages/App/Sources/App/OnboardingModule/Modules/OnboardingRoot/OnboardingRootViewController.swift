import AppUI
import TKUIKit
import UIKit

final class OnboardingRootViewController: TKHostingController<OnboardingRootScreen> {
    private let viewModel: OnboardingRootViewModelImplementation

    init(viewModel: OnboardingRootViewModelImplementation) {
        self.viewModel = viewModel
        super.init(
            content: OnboardingRootScreen(
                state: viewModel.state,
                onCreate: { [weak viewModel] in viewModel?.didTapCreate() },
                onImport: { [weak viewModel] in viewModel?.didTapImport() }
            )
        )
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The screen is full-bleed and its bar carries nothing. Left visible, the system bar lays its
    /// scroll-edge effect over the top of the screen and fades the glow out towards the status bar.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
}
