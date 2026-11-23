import TKLocalize
import TKUIKit
import UIKit

final class SendV3ViewController: GenericViewViewController<SendV3View> {
    enum Autofocus {
        case recipient
        case amount
    }

    private let viewModel: SendV3ViewModel
    private let autofocus: Autofocus

    private var isFirstAppear = true

    init(viewModel: SendV3ViewModel, autofocus: Autofocus = .recipient) {
        self.viewModel = viewModel
        self.autofocus = autofocus
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
        setupViewEvents()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard isFirstAppear else { return }
        isFirstAppear = false
        if let coordinator = transitionCoordinator, animated {
            coordinator.animate(alongsideTransition: nil) { _ in
                self.applyAutofocus()
            }
        } else {
            applyAutofocus()
        }
    }

    private func applyAutofocus() {
        switch autofocus {
        case .recipient:
            customView.recipientTextField.becomeFirstResponder()
        case .amount:
            customView.amountInputView.amountTextField.becomeFirstResponder()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        customView.navigationBar.layoutIfNeeded()
        let navigationBarHeight = customView.navigationBar.bounds.height
        customView.scrollView.contentInset.top = TKLiquidGlass.isEnabled
            ? max(0, navigationBarHeight - customView.scrollView.safeAreaInsets.top)
            : navigationBarHeight
    }
}

private extension SendV3ViewController {
    func setup() {
        view.backgroundColor = .Background.page

        setupNavigationBar()

        customView.amountInputView.textInputControl.delegate = viewModel.sendAmountTextFieldFormatter

        var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
        configuration.content.title = .plainString(TKLocales.Actions.paste)
        configuration.action = { [weak viewModel] in
            viewModel?.didTapCommentPasteButton()
        }
        customView.commentPasteButton.configuration = configuration

        configuration.padding = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configuration.action = { [weak viewModel] in
            viewModel?.didTapRecipientPasteButton()
        }
        customView.recipientPasteButton.configuration = configuration

        var scanConfiguration = TKButton.Configuration.fieldAccentButtonConfiguration()
        scanConfiguration.content.icon = .TKUIKit.Icons.Size28.qrViewFinder
        scanConfiguration.action = { [weak viewModel] in
            viewModel?.didTapRecipientScanButton()
        }
        customView.recipientScanButton.configuration = scanConfiguration

        customView.recipientTextField.accessibilityIdentifier = "input_field"
        customView.amountInputView.amountTextField.accessibilityIdentifier = "amount"
        customView.amountInputView.tokenView.accessibilityIdentifier = "send_token"
        customView.amountInputView.tokenView.tokenTitleAccessibilityIdentifier = "send_token_title"

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapGestureHandler))
        tapGestureRecognizer.delegate = self
        customView.addGestureRecognizer(tapGestureRecognizer)
    }

    func setupBindings() {
        viewModel.didUpdateTitle = { [weak self] title in
            self?.title = title?.string
            self?.customView.titleView.configure(
                model: TKUINavigationBarTitleView.Model(title: title)
            )
        }

        viewModel.didUpdateViewState = { [weak self] viewState in
            guard let self else { return }

            customView.amountInputView.tokenView.isUserInteractionEnabled = viewState.isTokenPickerEnabled
            customView.amountInputView.tokenView.switchImageView.isHidden = !viewState.isTokenPickerEnabled
            customView.amountInputView.balanceView.isSwapVisible = viewState.isSwapVisible

            customView.recipientTextField.isValid = viewState.isRecipientValid
            if let recipientDescription = viewState.recipientDescription {
                customView.recipientDescriptionLabel.setAttributedText(
                    recipientDescription.description,
                    actionItems: recipientDescription.actionItems
                )
                customView.recipientDescriptionContainer.isHidden = false
                customView.stackView.setCustomSpacing(8, after: customView.recipientTextField)
            } else {
                customView.recipientDescriptionLabel.attributedText = nil
                customView.recipientDescriptionContainer.isHidden = true
                customView.stackView.setCustomSpacing(
                    UIStackView.spacingUseDefault,
                    after: customView.recipientTextField
                )
            }

            switch viewState.balanceState.remaining {
            case .insufficient:
                customView.amountInputView.balanceView.remainingView.isHidden = true
                customView.amountInputView.balanceView.insufficientLabel.isHidden = false
            case let .remaining(value):
                customView.amountInputView.balanceView.remainingView.isHidden = false
                customView.amountInputView.balanceView.insufficientLabel.isHidden = true

                customView.amountInputView.balanceView.remainingView.remaining = "\(TKLocales.Send.remaining) \(value)"
            case let .balance(value):
                customView.amountInputView.balanceView.remainingView.isHidden = false
                customView.amountInputView.balanceView.insufficientLabel.isHidden = true

                customView.amountInputView.balanceView.remainingView.remaining = "\(TKLocales.Send.balance) \(value)"
            }
            customView.amountInputView.balanceView.convertedValue = viewState.balanceState.converted
            customView.amountInputView.balanceView.limitError = viewState.balanceState.limitError

            customView.continueButton.configuration = viewState.continueButtonConfiguration

            if let commentState = viewState.commentState {
                customView.commentInputView.isHidden = false
                customView.commentInputView.commentTextField.placeholder = commentState.placeholder
                customView.commentInputView.commentTextField.isValid = commentState.isValid
                if let description = commentState.description {
                    customView.commentInputView.descriptionLabel.setAttributedText(description, actionItems: commentState.actionItems)
                } else {
                    customView.commentInputView.descriptionLabel.attributedText = nil
                }
                customView.commentInputView.descriptionContainer.isHidden = commentState.description == nil
            } else {
                customView.commentInputView.isHidden = true
            }
        }

        viewModel.didUpdateRecipientPlaceholder = { [weak self] placeholder in
            self?.customView.recipientTextField.placeholder = placeholder
        }

        viewModel.didUpdateRecipient = { [weak self] recipient in
            self?.customView.recipientTextField.text = recipient
        }

        viewModel.didUpdateAmount = { [weak self] amount in
            self?.customView.amountInputView.amountTextField.text = amount
        }

        viewModel.didUpdateAmountPlaceholder = { [weak self] placeholder in
            self?.customView.amountInputView.amountTextField.placeholder = placeholder
        }

        viewModel.didUpdateAmountIsHidden = { [weak self] isHidden in
            self?.customView.amountInputView.isHidden = isHidden
        }

        viewModel.didUpdateToken = { [weak self] configuration in
            self?.customView.amountInputView.tokenView.configuration = configuration
        }

        viewModel.didUpdateComment = { [weak self] comment in
            self?.customView.commentInputView.commentTextField.text = comment
        }

        viewModel.didShowError = { message in
            ToastPresenter.showToast(configuration: .init(title: message))
        }

        viewModel.didUpdateCurrency = { [weak self] currency in
            self?.customView.amountInputView.amountTextField.currency = currency
        }
    }

    private func setupNavigationBar() {
        guard let navigationController,
              !navigationController.viewControllers.isEmpty
        else {
            return
        }
        if navigationController.viewControllers.count > 1 {
            customView.navigationBar.leftViews = [
                TKUINavigationBar.createBackButton {
                    navigationController.popViewController(animated: true)
                },
            ]
        }
        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.viewModel.didTapCloseButton()
            },
        ]
    }

    func setupViewEvents() {
        customView.recipientTextField.didUpdateText = { [weak viewModel] in
            viewModel?.didInputRecipient($0)
        }

        customView.amountInputView.didUpdateText = { [weak viewModel] in
            viewModel?.didInputAmount($0 ?? "")
        }

        customView.amountInputView.didTapTokenPicker = { [weak viewModel] in
            viewModel?.didTapWalletTokenPicker()
        }

        customView.amountInputView.balanceView.didTapMax = { [weak viewModel] in
            viewModel?.didTapMax()
        }

        customView.amountInputView.balanceView.didTapSwap = { [weak viewModel] in
            viewModel?.didTapSwap()
        }

        customView.commentInputView.commentTextField.didUpdateText = { [weak viewModel] in
            viewModel?.didInputComment($0)
        }
    }

    @objc
    func viewTapGestureHandler() {
        customView.endEditing(true)
    }
}

extension SendV3ViewController {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard touch.view?.isKind(of: UIControl.self) == false else {
            return false
        }
        return true
    }
}
