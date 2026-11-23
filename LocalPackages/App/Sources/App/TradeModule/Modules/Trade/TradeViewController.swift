import SwiftUI
import TKCoordinator
import TKUIKit
import UIKit

final class TradeViewController: UIViewController, ScrollViewController {
    private let viewModel: TradeViewModel
    private let hostingController: TKHostingController<TradeRootView>

    init(viewModel: TradeViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: TradeRootView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ScreenRenderTracker.shared.lifecycle(.viewDidLoad, for: .trade, from: self)

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
        ScreenRenderTracker.shared.lifecycle(.viewWillAppear, for: .trade, from: self)
        // Shelves load once per mode: a screen that has loaded them shows them without a refresh.
        switch viewModel.state {
        case .pending:
            break
        case let .refreshing(data, task: _):
            if !data.shelves.isEmpty {
                ScreenRenderTracker.shared.contentApplied(.cached, for: .trade)
            }
        case .loaded:
            ScreenRenderTracker.shared.contentApplied(.cached, for: .trade)
            ScreenRenderTracker.shared.finish(.trade)
        case let .failed(data):
            // Nothing retries a failed load on appearance, so the revisit still shows the failure.
            if !data.shelves.isEmpty {
                ScreenRenderTracker.shared.contentApplied(.cached, for: .trade)
            }
            ScreenRenderTracker.shared.failed(.trade, error: viewModel.shelvesErrorKind ?? .unknown)
        }

        viewModel.refreshFavoriteAssets()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ScreenRenderTracker.shared.lifecycle(.viewDidAppear, for: .trade, from: self)

        viewModel.viewDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ScreenRenderTracker.shared.abandon(.trade, by: self)

        viewModel.viewDidDisappear()
    }

    func scrollToTop() {
        viewModel.scrollToTop()
    }

    func scrollToGrid(id: String) {
        viewModel.scrollToGrid(id: id)
    }
}
