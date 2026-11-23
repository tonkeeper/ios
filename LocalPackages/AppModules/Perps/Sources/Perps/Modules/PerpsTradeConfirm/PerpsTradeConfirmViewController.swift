import SwiftUI
import TKUIKit
import UIKit

public final class PerpsTradeConfirmViewController<ViewModel: PerpsTradeConfirmViewModeling>: UIViewController {
    /// The screen was popped or dismissed for good. Called once it has disappeared, never on the way
    /// out: a back swipe the user gives up on starts a disappearance it never finishes.
    var didLeave: (() -> Void)?

    private let viewModel: ViewModel
    private let hostingController: TKHostingController<PerpsTradeConfirmView<ViewModel>>

    /// The SwiftUI header hands its buttons and title to the navigation item of the hosting controller,
    /// while the bar shows this controller's one.
    override public var navigationItem: UINavigationItem {
        TKLiquidGlass.isEnabled ? hostingController.navigationItem : super.navigationItem
    }

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: PerpsTradeConfirmView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
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

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tkUpdateNavigationBarForHeader(animated: animated)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            didLeave?()
        }
    }
}
