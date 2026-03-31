import TKUIKit
import UIKit

public final class TKRecoveryPhraseViewController: GenericViewViewController<TKRecoveryPhraseView> {
    private let viewModel: TKRecoveryPhraseViewModel

    init(viewModel: TKRecoveryPhraseViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupBindings()
        viewModel.viewDidLoad()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut
        ) {
            self.customView.listView.alpha = 1
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        transitionCoordinator?.animate(alongsideTransition: { _ in
            self.customView.listView.alpha = 0
        })
    }
}

private extension TKRecoveryPhraseViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [weak customView] model in
            customView?.configure(model: model)
        }
    }
}
