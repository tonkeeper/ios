import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class HistoryViewController: GenericViewViewController<HistoryView>, ScrollViewController {
    private var isTabViewsHidden: Bool = true {
        didSet { didUpdateIsTabViewsHidden() }
    }

    private let viewModel: HistoryViewModel
    private let historyListViewController: HistoryListViewController

    init(
        viewModel: HistoryViewModel,
        historyListViewController: HistoryListViewController
    ) {
        self.viewModel = viewModel
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

        viewModel.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        customView.navigationBar.layoutIfNeeded()
        customView.tabsView.layoutIfNeeded()
        historyListViewController.contentTopPadding = listContentTopPadding
    }

    func scrollToTop() {
        historyListViewController.scrollToTop()
    }
}

private extension HistoryViewController {
    func setup() {
        customView.navigationBar.title = TKLocales.History.title

        setupBindings()

        setupListViewController()
    }

    func setupBindings() {
        viewModel.didUpdateTabs = { [weak self] tabs in
            self?.customView.tabsView.items = tabs
        }

        viewModel.didUpdateSelectedTab = { [weak self] selectedTab in
            self?.customView.tabsView.selectedItem = selectedTab
        }

        viewModel.didUpdateIsConnecting = { [weak self] isConnecting in
            self?.customView.navigationBar.isConnecting = isConnecting
        }

        viewModel.didUpdateTabViewIsHidden = { [weak self] isHidden in
            self?.isTabViewsHidden = isHidden
        }
    }

    func setupListViewController() {
        addChild(historyListViewController)
        customView.listContainerView.addSubview(historyListViewController.view)
        historyListViewController.didMove(toParent: self)

        historyListViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(customView.listContainerView)
        }

        historyListViewController.didScroll = { [weak self] in
            guard let self else { return }
            let offset = max(0, $0.contentOffset.y + $0.adjustedContentInset.top)
            let navigationBarOffset = min(offset, customView.navigationBar.bounds.height)
            let tabsViewOffset = min(offset, customView.navigationBar.bounds.height - customView.safeAreaBar.bounds.height)

            customView.navigationBar.transform = CGAffineTransform(translationX: 0, y: -navigationBarOffset)
            customView.tabsView.transform = CGAffineTransform(translationX: 0, y: -tabsViewOffset)
        }
    }

    func didUpdateIsTabViewsHidden() {
        customView.tabsView.isHidden = isTabViewsHidden
        historyListViewController.contentTopPadding = listContentTopPadding
    }

    var listContentTopPadding: CGFloat {
        var result: CGFloat = 0
        result += customView.navigationBar.bounds.height
        if !isTabViewsHidden {
            result += customView.tabsView.bounds.height
        }
        return result
    }
}
