import TKLocalize
import TKUIKit
import UIKit

final class PasscodeInputViewController: GenericViewViewController<PasscodeInputView> {
    private let viewModel: PasscodeInputViewModel
    private let sensitiveContentController = TKSensitiveContentController()

    init(viewModel: PasscodeInputViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.viewWillAppear()

        sensitiveContentController.start(
            in: self,
            title: TKLocales.Toast.sensitiveScreenshotWarningPasscode
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sensitiveContentController.stop()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        viewModel.viewDidDisappear()
    }

    override func didMove(toParent parent: UIViewController?) {}
}

private extension PasscodeInputViewController {
    func setupBindings() {
        viewModel.didUpdateTitle = { [weak customView] title in
            customView?.title = title
        }

        viewModel.didUpdateState = { [weak customView] state, completion in
            customView?.setState(state, completion: { completion?() })
        }
    }
}
