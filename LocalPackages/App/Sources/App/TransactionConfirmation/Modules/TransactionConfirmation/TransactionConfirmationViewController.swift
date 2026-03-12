import TKLocalize
import TKUIKit
import UIKit

final class TransactionConfirmationViewController: GenericViewViewController<TransactionConfirmationView> {
    private let viewModel: TransactionConfirmationViewModel

    private let popUpViewController = TKPopUp.ViewController()

    init(viewModel: TransactionConfirmationViewModel) {
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
}

private extension TransactionConfirmationViewController {
    func setupBindings() {
        viewModel.didUpdateConfiguration = { [weak self] configuration in
            self?.popUpViewController.configuration = configuration
        }

        viewModel.didRequestSendAllConfirmation = { [weak self] tokenName, completion in
            self?.presentSendAllConfirmationAlert(tokenName: tokenName, completion: completion)
        }
    }

    func setup() {
        setupNavigationBar()
        setupModalContent()
    }

    private func setupNavigationBar() {
        customView.navigationBar.scrollView = popUpViewController.scrollView

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

    private func presentSendAllConfirmationAlert(tokenName: String, completion: @escaping (Bool) -> Void) {
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
}
