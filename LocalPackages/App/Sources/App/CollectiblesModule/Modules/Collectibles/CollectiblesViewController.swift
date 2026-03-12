import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class CollectiblesViewController: GenericViewViewController<CollectiblesView>, ScrollViewController {
    private let viewModel: CollectiblesViewModel
    private let collectiblesListViewController: CollectiblesListViewController

    /// for system navigation bar
    private var rightBarButtonActions: [() -> Void] = []

    init(
        viewModel: CollectiblesViewModel,
        collectiblesListViewController: CollectiblesListViewController
    ) {
        self.viewModel = viewModel
        self.collectiblesListViewController = collectiblesListViewController
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

        if !UIApplication.useSystemBarsAppearance {
            collectiblesListViewController.topInset = customView.navigationBar.bounds.height
        }
    }

    func scrollToTop() {
        collectiblesListViewController.scrollToTop()
    }
}

private extension CollectiblesViewController {
    func setup() {
        configureNavigationBar()
        setupListViewController()
        setupBindings()
    }

    func configureNavigationBar() {
        if UIApplication.useSystemBarsAppearance {
            navBarItemOwner.navigationItem.title = TKLocales.Collectibles.title
        } else {
            customView.navigationBar.title = TKLocales.Collectibles.title
            customView.navigationBar.scrollView = collectiblesListViewController.customView.collectionView
        }
    }

    func setupBindings() {
        viewModel.didUpdateIsLoading = { [weak self] isLoading in
            self?.customView.navigationBar.isLoading = isLoading
        }

        viewModel.didUpdateNavigationBarButtons = { [weak self] buttons in
            if UIApplication.useSystemBarsAppearance {
                self?.updateSystemNavigationBarButtons(buttons)
            } else {
                self?.customView.navigationBar.rightButtonItems = buttons
            }
        }
    }

    func setupListViewController() {
        addChild(collectiblesListViewController)
        customView.listContainerView.addSubview(collectiblesListViewController.view)
        collectiblesListViewController.didMove(toParent: self)

        collectiblesListViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(customView.listContainerView)
        }

        collectiblesListViewController.didScroll = { [weak self] scrollView in
            guard let self, !UIApplication.useSystemBarsAppearance else { return }
            let refreshControlHeight: CGFloat = {
                guard let refreshControl = scrollView.refreshControl else { return 0 }
                return refreshControl.isRefreshing ? refreshControl.bounds.height : 0
            }()
            let offset = min(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top - refreshControlHeight)
            let navigationBarOffset = min(offset, customView.navigationBar.bounds.height)
            customView.navigationBar.transform = CGAffineTransform(translationX: 0, y: -navigationBarOffset)
        }
    }
}

// MARK: - System Navigation Bar

private extension CollectiblesViewController {
    var navBarItemOwner: UIViewController {
        (parent as? CollectiblesContainerViewController) ?? self
    }

    func updateSystemNavigationBarButtons(_ buttonItems: [CollectiblesNavigationBar.ButtonItem]) {
        guard UIApplication.useSystemBarsAppearance else {
            return
        }

        rightBarButtonActions = buttonItems.map(\.action)

        navBarItemOwner.navigationItem.rightBarButtonItems = buttonItems.enumerated().map { index, item in
            let barItem: UIBarButtonItem
            switch item.content {
            case let .icon(image):
                barItem = UIBarButtonItem(
                    image: image,
                    style: .plain,
                    target: self,
                    action: #selector(didTapRightBarButton(_:))
                )
            case let .text(text):
                barItem = UIBarButtonItem(
                    title: text,
                    style: .plain,
                    target: self,
                    action: #selector(didTapRightBarButton(_:))
                )
            }
            barItem.tag = index
            return barItem
        }
    }

    @objc
    func didTapRightBarButton(_ sender: UIBarButtonItem) {
        let index = sender.tag
        guard index >= 0, index < rightBarButtonActions.count else { return }
        rightBarButtonActions[index]()
    }
}
