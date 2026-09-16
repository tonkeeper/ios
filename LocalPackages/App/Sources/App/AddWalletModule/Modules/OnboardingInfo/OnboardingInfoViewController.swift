import AppUI
import TKUIKit
import UIKit

final class OnboardingInfoViewController: TKHostingController<OnboardingInfoScreen>, TKOwnHeaderScreen {
    var didTapContinue: (() -> Void)?
    var isInteractivePopDisabled: Bool = false

    private let state: OnboardingInfoScreenState
    private var isTransitionInProgress = false
    private var showsLoader = false
    private var onBack: (() -> Void)?
    private var skip: OnboardingInfoScreen.SkipAction?

    init(state: OnboardingInfoScreenState) {
        self.state = state
        super.init(
            content: OnboardingInfoScreen(
                state: state,
                onContinue: {}
            )
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateContent()
    }

    func setupHeaderBackButton() {
        setupHeaderBackButton { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    func setupHeaderBackButton(_ action: @escaping () -> Void) {
        onBack = action
        updateContent()
    }

    func setupHeaderSkipButton(title: String, _ action: @escaping () -> Void) {
        skip = OnboardingInfoScreen.SkipAction(title: title, action: action)
        updateContent()
    }

    func beginTransition(showsLoader: Bool) -> Bool {
        guard !isTransitionInProgress else { return false }
        isTransitionInProgress = true
        self.showsLoader = showsLoader
        updateContent()
        return true
    }

    func endTransition() {
        isTransitionInProgress = false
        showsLoader = false
        updateContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBar(animated: animated)
        if isTransitionInProgress,
           let navigationController,
           let fromViewController = transitionCoordinator?.viewController(forKey: .from),
           fromViewController.navigationController === navigationController
        {
            endTransition()
        }
        if isInteractivePopDisabled {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreNavigationBar(animated: animated)
        if isInteractivePopDisabled {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

private extension OnboardingInfoViewController {
    func updateContent() {
        content = OnboardingInfoScreen(
            state: state,
            areActionsEnabled: !isTransitionInProgress,
            showsLoader: showsLoader,
            onBack: onBack,
            skip: skip,
            onContinue: { [weak self] in
                self?.didTapContinue?()
            }
        )
    }
}
