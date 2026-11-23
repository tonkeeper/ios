import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class TradeAssetDetailsViewController: UIViewController {
    private let viewModel: TradeAssetDetailsViewModel
    private let hostingController: TKHostingController<TradeAssetDetailsView>

    /// The SwiftUI header hands its buttons and title to the navigation item of the hosting controller,
    /// while the bar shows this controller's one.
    override var navigationItem: UINavigationItem {
        TKLiquidGlass.isEnabled ? hostingController.navigationItem : super.navigationItem
    }

    init(viewModel: TradeAssetDetailsViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: TradeAssetDetailsView(viewModel: viewModel))
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
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tkUpdateNavigationBarForHeader(animated: animated)
        viewModel.handleAppear()
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
