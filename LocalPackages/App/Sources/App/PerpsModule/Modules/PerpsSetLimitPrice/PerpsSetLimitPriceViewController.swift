import SwiftUI
import TKUIKit
import UIKit

final class PerpsSetLimitPriceViewController: UIViewController {
    private let viewModel: PerpsSetLimitPriceViewModel
    private let hostingController: TKHostingController<PerpsSetLimitPriceView>

    init(viewModel: PerpsSetLimitPriceViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: PerpsSetLimitPriceView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
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
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let dismissing = isBeingDismissed || navigationController?.isBeingDismissed == true
        if dismissing {
            view.endEditing(true)
        }
    }
}
