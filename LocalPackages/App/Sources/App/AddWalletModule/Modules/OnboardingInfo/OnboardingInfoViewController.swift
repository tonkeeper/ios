import TKUIKit
import UIKit

final class OnboardingInfoViewController: GenericViewViewController<OnboardingInfoView> {
    var didTapContinue: (() -> Void)?
    var isInteractivePopDisabled: Bool = false

    private let model: OnboardingInfoView.Model

    init(model: OnboardingInfoView.Model) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        customView.configure(model: model)
        var configuration = customView.continueButton.configuration
        configuration.action = { [weak self] in
            self?.didTapContinue?()
        }
        customView.continueButton.configuration = configuration
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isInteractivePopDisabled {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isInteractivePopDisabled {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
