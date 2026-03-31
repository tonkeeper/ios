import TKLocalize
import TKUIKit
import UIKit

final class InsertAmountViewController: GenericViewViewController<InsertAmountView>, KeyboardObserving {
    private let viewModel: InsertAmountViewModelProtocol
    private let amountInputViewController: UIViewController
    private let providerView = InsertAmountProviderView()

    init(
        viewModel: InsertAmountViewModelProtocol,
        amountInputViewController: UIViewController
    ) {
        self.viewModel = viewModel
        self.amountInputViewController = amountInputViewController
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
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerForKeyboardEvents()
        amountInputViewController.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardEvents()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        customView.navigationBar.layoutIfNeeded()
        customView.scrollView.contentInset.top = customView.navigationBar.bounds.height
    }

    func keyboardWillShow(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration,
              let keyboardHeight = notification.keyboardSize?.height else { return }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
            self.customView.keyboardHeight = keyboardHeight + 16
            self.customView.layoutIfNeeded()
        }
    }

    func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration else { return }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
            self.customView.keyboardHeight = 0
            self.customView.layoutIfNeeded()
        }
    }
}

private extension InsertAmountViewController {
    func setup() {
        setupNavigationBar()

        customView.scrollView.contentInsetAdjustmentBehavior = .never

        addChild(amountInputViewController)
        customView.setAmountInputView(amountInputViewController.view)
        amountInputViewController.didMove(toParent: self)

        customView.setDetailsView(providerView)

        providerView.didTap = { [weak viewModel] in
            viewModel?.didTapProviderView()
        }
    }

    func setupNavigationBar() {
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton { [weak self] in
                self?.viewModel.didTapBackButton()
            },
        ]
        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.viewModel.didTapCloseButton()
            },
        ]
    }

    func setupBindings() {
        viewModel.didUpdateTitle = { [weak self] title in
            self?.customView.titleView.configure(
                model: TKUINavigationBarTitleView.Model(
                    title: title.withTextStyle(
                        .h3,
                        color: .Text.primary,
                        alignment: .center,
                        lineBreakMode: .byTruncatingTail
                    )
                )
            )
        }

        viewModel.didUpdateButton = { [weak self] config in
            self?.customView.continueButton.configuration = config
        }

        viewModel.didUpdateProviderView = { [weak self] state in
            self?.providerView.providerViewState = state
        }

        viewModel.didUpdateProviderViewHidden = { [weak self] hidden in
            self?.customView.detailsViewContainer.isHidden = hidden
        }

        viewModel.didUpdateAmountError = { [weak self] message in
            guard let self else { return }
            self.customView.amountErrorLabel.text = message
            self.customView.amountErrorLabel.isHidden = (message == nil || message?.isEmpty == true)
        }

        viewModel.didShowError = { message in
            ToastPresenter.showToast(configuration: .init(title: message))
        }
    }
}
