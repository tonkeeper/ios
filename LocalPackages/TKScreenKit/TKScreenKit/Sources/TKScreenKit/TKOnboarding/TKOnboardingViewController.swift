import TKUIKit
import UIKit

public final class TKOnboardingViewController: GenericViewViewController<TKOnboardingView> {
    private let viewModel: TKOnboardingViewModel

    init(viewModel: TKOnboardingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension TKOnboardingViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [customView] model in
            customView.configure(model: model)
        }
    }
}
