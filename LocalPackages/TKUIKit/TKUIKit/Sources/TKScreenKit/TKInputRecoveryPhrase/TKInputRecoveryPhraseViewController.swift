import TKUIKit
import UIKit

public final class TKInputRecoveryPhraseViewController: GenericViewViewController<TKInputRecoveryPhraseView>, KeyboardObserving {
    private let viewModel: TKInputRecoveryPhraseViewModel

    init(viewModel: TKInputRecoveryPhraseViewModel) {
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

private extension TKInputRecoveryPhraseViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [customView] model in
            customView.configure(model: model)
        }

        viewModel.didUpdateContinueButton = { [weak customView] configuration in
            customView?.continueButton.configuration = configuration
        }

        viewModel.didUpdateInputValidationState = { [customView] index, isValid in
            customView.inputTextFields[index].isValid = isValid
        }

        viewModel.didUpdateText = { [customView] index, text in
            customView.inputTextFields[index].text = text
        }

        viewModel.didSelectInput = { [customView] index in
            customView.scrollToInput(at: index, animationDuration: 0.35)
        }

        viewModel.didPaste = { [customView] index in
            customView.inputTextFields[index].becomeFirstResponder()
        }

        viewModel.didPastePhrase = { [customView] in
            customView.scrollToBottom(animationDuration: 0.35)
            customView.endEditing(true)
        }

        viewModel.didUpdateSuggests = { [customView] model in
            customView.configureSuggests(model: model)
        }
    }
}
