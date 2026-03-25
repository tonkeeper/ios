import TKUIKit
import UIKit

final class OnboardingRootViewController: GenericViewViewController<OnboardingRootView> {
    private let viewModel: OnboardingRootViewModel

    init(viewModel: OnboardingRootViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        customView.termsTextView.delegate = self
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension OnboardingRootViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [customView] model in
            customView.configure(model: model)
        }
    }
}

extension OnboardingRootViewController: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith url: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        UIApplication.shared.open(url)
        return false
    }
}
