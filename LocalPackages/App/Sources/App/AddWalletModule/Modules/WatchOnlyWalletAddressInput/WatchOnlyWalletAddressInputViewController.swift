import TKLocalize
import TKUIKit
import UIKit

final class WatchOnlyWalletAddressInputViewController: GenericViewViewController<WatchOnlyWalletAddressInputView>, KeyboardObserving {
    private let viewModel: WatchOnlyWalletAddressInputViewModel

    init(viewModel: WatchOnlyWalletAddressInputViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        setupViewActions()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardEvents()
        customView.textField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardEvents()
    }

    func keyboardWillShow(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration,
              let keyboardHeight = notification.keyboardSize?.height else { return }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
            self.customView.keyboardHeight = keyboardHeight
        }
    }

    func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration else { return }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
            self.customView.keyboardHeight = 0
        }
    }
}

private extension WatchOnlyWalletAddressInputViewController {
    func setup() {
        var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
        configuration.content.title = .plainString(TKLocales.Actions.paste)
        configuration.action = { [weak self] in
            guard let pasteboardString = UIPasteboard.general.string else { return }
            self?.customView.textField.text = pasteboardString
            self?.viewModel.text = pasteboardString
        }
        customView.addressPasteButton.configuration = configuration
    }

    func setupBindings() {
        viewModel.didUpdateModel = { [weak customView] model in
            customView?.configure(model: model)
        }

        viewModel.didUpdateContinueButton = { [weak customView] configuration in
            customView?.continueButton.configuration = configuration
        }

        viewModel.didUpdateIsValid = { [weak customView] isValid in
            customView?.textField.isValid = isValid
        }
    }

    func setupViewActions() {
        customView.textField.didUpdateText = { [weak viewModel] text in
            viewModel?.text = text
        }
    }
}
