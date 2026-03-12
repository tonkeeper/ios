import Combine
import KeeperCore
import SnapKit
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

final class NativeSwapViewController<ViewModel: NativeSwapViewModel>: UIViewController, UIGestureRecognizerDelegate {
    private let viewModel: ViewModel
    private let customView = NativeSwapView()
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = customView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBinding()
        viewModel.send(.didViewLoad)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.send(.didViewAppear)
        customView.setSendTextFieldsFocus(viewModel.isSendFocused)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.send(.didViewDisappear)
    }

    @objc
    private func didToggleKeyboard() {
        customView.endEditing(true)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard touch.view is UIControl else { return true }

        return false
    }
}

private extension NativeSwapViewController {
    func setup() {
        let title = TKLocales.NativeSwap.Screen.Swap.title

        customView.titleView.configure(
            model: TKUINavigationBarTitleView.Model(
                title: title.withTextStyle(.h3, color: .Text.primary)
            )
        )
        customView.backgroundColor = .Background.page

        customView.setTextFieldsDelegate(viewModel.amountTextFieldFormatter)

        setupNavigationBar()
        setupTapGesture()
    }

    func setupNavigationBar() {
        guard let navigationController, !navigationController.viewControllers.isEmpty else { return }

        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.viewModel.didTapClose?()
            },
        ]
    }

    func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didToggleKeyboard))
        tapGesture.delegate = self
        customView.addGestureRecognizer(tapGesture)
    }

    func setupBinding() {
        customView.didUpdateSendText = { [weak self] text in
            self?.viewModel.send(.didUpdateAmount(text, true))
        }

        customView.didUpdateReceiveText = { [weak self] text in
            self?.viewModel.send(.didUpdateAmount(text, false))
        }

        customView.didTapMax = { [weak self] in
            self?.viewModel.handleMaxTap()
        }

        customView.didTapSendTokenPicker = { [weak self] in
            self?.viewModel.handleTokenPickerTap(isSend: true)
        }

        customView.didTapReceiveTokenPicker = { [weak self] in
            self?.viewModel.handleTokenPickerTap(isSend: false)
        }

        customView.didTapSwap = { [weak self] in
            self?.viewModel.handleSwapTap()
        }

        customView.didTapClear = { [weak self] in
            self?.viewModel.handleClearTap()
        }

        customView.didTapContinue = { [weak self] in
            self?.viewModel.handleContinueTap()
        }

        customView.didTapURL = { [weak self] url in
            self?.openURL(url)
        }

        viewModel.viewState
            .sink { [weak self] state in
                guard let self else { return }

                customView.update(state)
            }
            .store(in: &subscriptions)
    }

    private func openURL(_ url: URL) {
        let title: String = {
            if url.absoluteString.contains("privacy") {
                return TKLocales.NativeSwapScreen.Privacy.stonfiPrivacyTitle
            }

            if url.absoluteString.contains("terms") {
                return TKLocales.NativeSwapScreen.Privacy.stonfiTermsTitle
            }

            return "STON.fi"
        }()

        let viewController = TKBridgeWebViewController(
            initialURL: url,
            initialTitle: title,
            jsInjection: nil,
            configuration: .default,
            deeplinkHandler: nil
        )
        present(viewController, animated: true)
    }
}
