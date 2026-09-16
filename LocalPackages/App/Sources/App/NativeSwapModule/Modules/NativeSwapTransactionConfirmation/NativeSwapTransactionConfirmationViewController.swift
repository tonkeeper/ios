import SwiftUI
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationViewController: GenericViewViewController<NativeSwapTransactionConfirmationView> {
    private let popUpViewController = TKPopUp.ViewController()
    private weak var infoHintSourceView: UIView?

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
        dismissInfoHint()
        viewModel.viewDidDisappear()
    }
}

private extension NativeSwapTransactionConfirmationViewController {
    func setupBindings() {
        viewModel.didTapPop = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        viewModel.didUpdateConfiguration = { [weak self] configuration in
            self?.dismissInfoHint()
            self?.popUpViewController.configuration = configuration
        }
        viewModel.didRequestSendAllConfirmation = { [weak self] tokenName, completion in
            self?.presentSendAllConfirmationAlert(
                tokenName: tokenName,
                completion: completion
            )
        }
        viewModel.didRequestSlippageInfo = { [weak self] sourceView in
            self?.showSlippageInfoHint(sourceView: sourceView)
        }
        viewModel.didRequestValueDifferenceInfo = { [weak self] sourceView in
            self?.showValueDifferenceInfoHint(sourceView: sourceView)
        }
        viewModel.didRequestTemporaryReserveInfo = { [weak self] reserveAmount, sourceView in
            self?.showTemporaryReserveInfoHint(reserveAmount: reserveAmount, sourceView: sourceView)
        }
        viewModel.didRequestBatteryTemporaryReserveInfo = { [weak self] reserveAmount, sourceView in
            self?.showBatteryTemporaryReserveInfoHint(reserveAmount: reserveAmount, sourceView: sourceView)
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

    private func showSlippageInfoHint(sourceView: UIView) {
        let text = TKLocales.NativeSwap.Screen.Confirm.Field.Slippage.info
        showInfoHint(sourceView: sourceView, text: text)
    }

    private func showValueDifferenceInfoHint(sourceView: UIView) {
        let text = TKLocales.NativeSwap.Screen.Confirm.Field.ValueDifference.info
        showInfoHint(sourceView: sourceView, text: text)
    }

    private func showTemporaryReserveInfoHint(reserveAmount: String, sourceView: UIView) {
        let text = TKLocales.NativeSwap.Screen.Confirm.Field.TemporaryReserve.info(reserveAmount)
        showInfoHint(sourceView: sourceView, text: text)
    }

    private func showBatteryTemporaryReserveInfoHint(reserveAmount: String, sourceView: UIView) {
        let text = TKLocales.NativeSwap.Screen.Confirm.Field.TemporaryReserve.batteryInfo(reserveAmount)
        showInfoHint(sourceView: sourceView, text: text)
    }

    private func showInfoHint(sourceView: UIView, text: String) {
        let didShow = HintController.show(
            sourceView: sourceView,
            configuration: HintConfiguration(
                position: HintPosition(
                    tailParameters: TKHintTextView.tailParameters,
                    horizontal: .default,
                    vertical: .init(absolute: 7),
                    direction: .bottomCenter
                ),
                maximumWidth: 200,
                animationStyle: .bouncing
            ),
            didHide: { [weak self, weak sourceView] in
                guard let self, self.infoHintSourceView === sourceView else { return }
                self.infoHintSourceView = nil
            },
            contentViewControllerProvider: { position in
                let hostingController = TKHostingController(
                    content: TKHintTextView(
                        text: text,
                        position: position
                    )
                )
                hostingController.view.backgroundColor = .clear
                return hostingController
            }
        )

        if didShow {
            infoHintSourceView = sourceView
        }
    }

    private func dismissInfoHint() {
        guard let infoHintSourceView else { return }
        self.infoHintSourceView = nil
        HintController.dismiss(sourceView: infoHintSourceView)
    }
}
