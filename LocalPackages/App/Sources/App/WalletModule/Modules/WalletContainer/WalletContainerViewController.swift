import SnapKit
import TKCoordinator
import TKUIKit
import UIKit

protocol WalletContainerBalanceViewController: UIViewController {
    var didScroll: ((CGFloat) -> Void)? { get set }
}

final class WalletContainerViewController: GenericViewViewController<WalletContainerView>, ScrollViewController {
    private let viewModel: WalletContainerViewModel

    private var walletBalanceViewController: WalletContainerBalanceViewController

    private let topBarState = WalletContainerTopBarState()
    private lazy var topBarHostingController = TKHostingController(
        content: WalletContainerTopBarView(state: topBarState)
    )

    func historyButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        guard isViewLoaded else {
            return
        }
        view.layoutIfNeeded()
        topBarState.waitForHistoryButtonAnchorView(completion)
    }

    func walletButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        guard isViewLoaded else {
            return
        }
        view.layoutIfNeeded()
        topBarState.waitForWalletButtonAnchorView(completion)
    }

    init(
        viewModel: WalletContainerViewModel,
        walletBalanceViewController: WalletContainerBalanceViewController
    ) {
        self.viewModel = viewModel
        self.walletBalanceViewController = walletBalanceViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        setupBindings()
        viewModel.viewDidLoad()

        addChild(walletBalanceViewController)
        customView.walletBalanceContainerView.addSubview(walletBalanceViewController.view)
        walletBalanceViewController.didMove(toParent: self)

        walletBalanceViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(customView.walletBalanceContainerView)
        }

        walletBalanceViewController.didScroll = { [weak self] yOffset in
            self?.topBarState.setSeparatorHidden(yOffset <= 0)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        customView.layoutIfNeeded()

        if let topBarView = customView.topBarView {
            walletBalanceViewController.additionalSafeAreaInsets.top = topBarView.frame.height - customView.safeAreaInsets.top
        }
    }

    func scrollToTop() {
        (walletBalanceViewController as? ScrollViewController)?.scrollToTop()
    }
}

private extension WalletContainerViewController {
    func setupTopBar() {
        addChild(topBarHostingController)
        topBarHostingController.view.backgroundColor = .clear
        customView.setTopBarView(topBarHostingController.view)
        topBarHostingController.didMove(toParent: self)
    }

    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            self?.topBarState.model = model
        }
    }
}
