import AppUI
import SwiftUI
import TKUIKit
import UIKit

final class MultichainSwapViewController: UIViewController {
    private let viewModel: MultichainSwapViewModel
    private let hostingController: TKHostingController<MultichainSwapViewContainer>
    private var hasAppearedBefore = false

    init(viewModel: MultichainSwapViewModel) {
        self.viewModel = viewModel
        hostingController = TKHostingController(
            content: MultichainSwapViewContainer(viewModel: viewModel)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppearedBefore, isReturningFromPushedController {
            viewModel.requestFocusOnAppear()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppearedBefore {
            viewModel.requestFocusOnAppear()
        }
        hasAppearedBefore = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            view.endEditing(true)
        }
    }

    private var isReturningFromPushedController: Bool {
        guard let coordinator = transitionCoordinator,
              coordinator.viewController(forKey: .to) === self,
              let fromViewController = coordinator.viewController(forKey: .from)
        else {
            return false
        }
        return fromViewController.navigationController === navigationController
    }
}
