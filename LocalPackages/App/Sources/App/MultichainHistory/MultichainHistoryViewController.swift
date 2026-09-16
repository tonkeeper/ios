import Foundation
import SwiftUI
import TKUIKit
import UIKit

final class MultichainHistoryViewController: UIViewController {
    private let hostingController: TKHostingController<MultichainHistoryView>
    private var wasNavigationBarHidden: Bool?

    init(
        viewModel: MultichainHistoryViewModelImplementation,
        onClose: (() -> Void)? = nil,
        onOpenTransaction: @escaping (URL, String?) -> Void = { _, _ in }
    ) {
        self.hostingController = TKHostingController(
            content: MultichainHistoryView(
                viewModel: viewModel,
                onClose: onClose,
                onOpenTransaction: onOpenTransaction
            )
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if wasNavigationBarHidden == nil {
            wasNavigationBarHidden = navigationController?.isNavigationBarHidden
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let wasNavigationBarHidden else { return }
        navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: animated)
    }
}
