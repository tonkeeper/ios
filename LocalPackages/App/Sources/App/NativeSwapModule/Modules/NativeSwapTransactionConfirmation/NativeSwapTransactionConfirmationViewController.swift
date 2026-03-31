import SnapKit
import SwiftUI
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationViewController: GenericViewViewController<NativeSwapTransactionConfirmationView> {
    private let popUpViewController = TKPopUp.ViewController()
    private var slippageSnackbarView: UIView?

    private let viewModel: NativeSwapTransactionConfirmationViewModel

    init(viewModel: NativeSwapTransactionConfirmationViewModel) {
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
        viewModel.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.viewDidDisappear()
    }
}

private extension NativeSwapTransactionConfirmationViewController {
    func setupBindings() {
        viewModel.didTapPop = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        viewModel.didUpdateConfiguration = { [weak self] configuration in
            self?.popUpViewController.configuration = configuration
        }
        viewModel.didRequestSendAllConfirmation = { [weak self] tokenName, completion in
            self?.presentSendAllConfirmationAlert(
                tokenName: tokenName,
                completion: completion
            )
        }
        viewModel.didRequestSlippageInfo = { [weak self] in
            self?.showSlippageInfoSnackbar()
        }
    }

    func setup() {
        setupNavigationBar()
        setupModalContent()
    }

    private func setupNavigationBar() {
        let title = TKLocales.NativeSwap.Screen.Confirm.title

        customView.titleView.configure(
            model: TKUINavigationBarTitleView.Model(
                title: title.withTextStyle(.h3, color: .Text.primary)
            )
        )
        customView.backgroundColor = .Background.page
        customView.navigationBar.scrollView = popUpViewController.scrollView

        guard let navigationController, !navigationController.viewControllers.isEmpty else { return }

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

    private func presentSendAllConfirmationAlert(
        tokenName: String,
        completion: @escaping (Bool) -> Void
    ) {
        let message = TKLocales.Send.Alert.message(tokenName)
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel, handler: { _ in
            completion(false)
        }))
        alert.addAction(UIAlertAction(title: TKLocales.Actions.continueAction, style: .destructive, handler: { _ in
            completion(true)
        }))
        present(alert, animated: true)
    }

    func setupModalContent() {
        addChild(popUpViewController)
        customView.embedContent(popUpViewController.view)
        popUpViewController.didMove(toParent: self)
    }

    private func showSlippageInfoSnackbar() {
        slippageSnackbarView?.removeFromSuperview()

        let text = TKLocales.NativeSwap.Screen.Confirm.Field.Slippage.info
        let swiftUIView = SnackbarContentView(text: text) { [weak self] in
            self?.slippageSnackbarView?.removeFromSuperview()
        }
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        customView.addSubview(hostingController.view)

        if let sliderView = findSlider(in: customView) {
            hostingController.view.snp.makeConstraints { make in
                make.bottom.equalTo(sliderView.snp.top)
                make.left.right.equalTo(customView).inset(16)
            }
        } else {
            hostingController.view.snp.makeConstraints { make in
                make.bottom.equalTo(customView).inset(140)
                make.left.right.equalTo(customView).inset(16)
            }
        }

        hostingController.view.alpha = 0
        slippageSnackbarView = hostingController.view

        UIView.animate(withDuration: 0.3) {
            hostingController.view.alpha = 1
        }
    }

    private func findSlider(in view: UIView) -> UIView? {
        if view is TKSlider {
            return view
        }

        for subview in view.subviews {
            if let found = findSlider(in: subview) {
                return found
            }
        }

        return nil
    }
}

private struct SnackbarContentView: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .multilineTextAlignment(.leading)
                .font(.init(TKTextStyle.body2.font))
                .foregroundColor(Color(uiColor: .Text.primary))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            Spacer(minLength: 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .Background.contentTint))
        )
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.close)
            }
            .tint(.init(uiColor: .Icon.primary))
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}
