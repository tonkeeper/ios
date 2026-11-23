import AppUI
import Combine
import SwiftUI
import TKUIKit
import UIKit

final class MultichainSwapViewController: UIViewController {
    private let viewModel: MultichainSwapViewModel
    private let hostingController: TKHostingController<MultichainSwapViewContainer>
    private var hasAppearedBefore = false
    private var modalityUpdates: AnyCancellable?

    /// The SwiftUI header hands its buttons and title to the navigation item of the hosting controller,
    /// while the bar shows this controller's one.
    override var navigationItem: UINavigationItem {
        TKLiquidGlass.isEnabled ? hostingController.navigationItem : super.navigationItem
    }

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
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Swiped away while a swap is on its way, the screen would take the swap's outcome along.
        modalityUpdates = viewModel.$confirmationPhase
            .map { $0 == .swapping }
            .removeDuplicates()
            .sink { [weak self] isSwapping in
                self?.navigationController?.isModalInPresentation = isSwapping
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
}
