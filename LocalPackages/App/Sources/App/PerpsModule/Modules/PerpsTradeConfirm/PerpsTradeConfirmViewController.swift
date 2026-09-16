import SwiftUI
import TKUIKit
import UIKit

final class PerpsTradeConfirmViewController: UIViewController {
    private let viewModel: PerpsTradeConfirmViewModel
    private let hostingController: TKHostingController<PerpsTradeConfirmView>

    init(viewModel: PerpsTradeConfirmViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: PerpsTradeConfirmView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        navigationController?.setNavigationBarHidden(true, animated: false)

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
}
