import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class SpamViewController: GenericViewViewController<SpamView>, ScrollViewController {
    private let historyListViewController: HistoryListViewController

    init(historyListViewController: HistoryListViewController) {
        self.historyListViewController = historyListViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        customView.navigationBar.layoutIfNeeded()
        historyListViewController.contentTopPadding = listContentTopPadding
    }

    func scrollToTop() {
        historyListViewController.scrollToTop()
    }
}

private extension SpamViewController {
    func setup() {
        setupNavigationBar()
        setupTitleView()
        setupListViewController()
    }

    func setupTitleView() {
        customView.titleView.configure(
            model: TKUINavigationBarTitleView.Model(
                title: TKLocales.History.Tab.spam,
                caption: nil
            )
        )
    }

    func setupNavigationBar() {
        guard let navigationController,
              !navigationController.viewControllers.isEmpty
        else {
            return
        }
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton {
                navigationController.popViewController(animated: true)
            },
        ]
    }

    func setupListViewController() {
        addChild(historyListViewController)
        customView.listContainerView.addSubview(historyListViewController.view)
        historyListViewController.didMove(toParent: self)

        historyListViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(customView.listContainerView)
        }
    }

    var listContentTopPadding: CGFloat {
        return customView.navigationBar.bounds.height
    }
}
