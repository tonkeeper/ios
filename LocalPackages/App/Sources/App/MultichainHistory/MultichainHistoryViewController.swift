import Foundation
import PerpsModels
import SwiftUI
import TKUIKit
import UIKit

final class MultichainHistoryViewController: UIViewController {
    private let hostingController: TKHostingController<MultichainHistoryView>
    private let viewModel: MultichainHistoryViewModelImplementation
    private var wasNavigationBarHidden: Bool?

    /// The SwiftUI header hands its buttons and title to the navigation item of the hosting controller,
    /// while the bar shows this controller's one.
    override var navigationItem: UINavigationItem {
        TKLiquidGlass.isEnabled ? hostingController.navigationItem : super.navigationItem
    }

    init(
        viewModel: MultichainHistoryViewModelImplementation,
        onClose: (() -> Void)? = nil,
        onOpenTransaction: @escaping (URL, String?) -> Void = { _, _ in },
        onSelectPerpsEvent: ((PerpsHistoryEvent) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(
            content: MultichainHistoryView(
                viewModel: viewModel,
                onClose: onClose,
                onOpenTransaction: onOpenTransaction,
                onSelectPerpsEvent: onSelectPerpsEvent
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
        ScreenRenderTracker.shared.lifecycle(.viewDidLoad, for: .history, from: viewModel)

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
        ScreenRenderTracker.shared.lifecycle(.viewWillAppear, for: .history, from: viewModel)
        if !TKLiquidGlass.isEnabled, wasNavigationBarHidden == nil {
            wasNavigationBarHidden = navigationController?.isNavigationBarHidden
        }
        tkUpdateNavigationBarForHeader(animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ScreenRenderTracker.shared.lifecycle(.viewDidAppear, for: .history, from: viewModel)
        viewModel.screenDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Under liquid glass the screen that comes on top sets the bar itself, so nothing is saved.
        guard let wasNavigationBarHidden else { return }
        navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ScreenRenderTracker.shared.abandon(.history, by: viewModel)
    }
}
