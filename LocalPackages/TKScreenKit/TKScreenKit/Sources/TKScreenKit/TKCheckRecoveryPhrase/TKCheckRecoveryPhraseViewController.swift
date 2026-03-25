import TKUIKit
import UIKit

public final class TKCheckRecoveryPhraseViewController: GenericViewViewController<TKCheckRecoveryPhraseView>, KeyboardObserving {
    private let viewModel: TKCheckRecoveryPhraseViewModel

    init(viewModel: TKCheckRecoveryPhraseViewModel) {
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

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardEvents()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        customView.inputTextFields.first?.becomeFirstResponder()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardEvents()
    }

    public func keyboardWillShow(_ notification: Notification) {
        guard let keyboardSize = notification.keyboardSize else { return }
        customView.scrollView.contentInset.bottom = keyboardSize.height - view.safeAreaInsets.bottom
    }

    public func keyboardWillHide(_ notification: Notification) {
        customView.scrollView.contentInset.bottom = 0
    }
}

private extension TKCheckRecoveryPhraseViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [weak customView] model in
            customView?.configure(model: model)
        }

        viewModel.didUpdateInputValidationState = { [weak customView] index, isValid in
            customView?.inputTextFields[index].isValid = isValid
        }

        viewModel.didUpdateIsButtonEnabled = { [weak customView] isEnabled in
            customView?.continueButton.isEnabled = isEnabled
        }

        viewModel.didUpdateContinueButton = { [weak customView] configuration in
            customView?.continueButton.configuration = configuration
        }
    }
}
