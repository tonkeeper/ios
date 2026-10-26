import AppUI
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class TransactionConfirmationViewController: UIViewController {
    private let viewModel: TransactionConfirmationViewModel
    private var hostingController: TKHostingController<ConfirmActionView>?

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
        view.backgroundColor = .Background.page
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension TransactionConfirmationViewController {
    func setupBindings() {
        viewModel.didUpdateState = { [weak self] state in
            self?.render(state)
        }

        viewModel.didRequestSendAllConfirmation = { [weak self] tokenName, completion in
            self?.presentSendAllConfirmationAlert(tokenName: tokenName, completion: completion)
        }
    }

    func render(_ state: ConfirmActionState) {
        let content = ConfirmActionView(
            state: state,
            onBack: backAction,
            onClose: { [weak self] in
                self?.viewModel.didTapCloseButton()
            }
        )
        if let hostingController {
            hostingController.content = content
            return
        }
        let hostingController = TKHostingController(content: content)
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    var backAction: (() -> Void)? {
        guard let navigationController, navigationController.viewControllers.count > 1 else { return nil }
        return { [weak navigationController] in
            navigationController?.popViewController(animated: true)
        }
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
}
