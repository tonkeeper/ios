import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class BrowserViewController: GenericViewViewController<BrowserView>, ScrollViewController {
    private let viewModel: BrowserViewModel

    private weak var selectedViewController: ScrollViewController?

    private let exploreViewController: BrowserExploreViewController
    private let connectedViewController: BrowserConnectedViewController

    /// for system navigation bar
    private var selectedTab: SelectedTab = .explore {
        didSet {
            updateSelectedButton()
        }
    }

    private lazy var exploreButton = UIBarButtonItem(
        title: TKLocales.Browser.Tab.explore,
        style: .plain,
        target: self,
        action: #selector(didTapExploreButton)
    )

    private lazy var connectedButton = UIBarButtonItem(
        title: TKLocales.Browser.Tab.connected,
        style: .plain,
        target: self,
        action: #selector(didTapConnectedButton)
    )

    init(
        viewModel: BrowserViewModel,
        exploreViewController: BrowserExploreViewController,
        connectedViewController: BrowserConnectedViewController
    ) {
        self.viewModel = viewModel
        self.exploreViewController = exploreViewController
        self.connectedViewController = connectedViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !UIApplication.useSystemBarsAppearance {
            navigationController?.setNavigationBarHidden(true, animated: true)
        }

        viewModel.viewWillAppear()
    }

    func scrollToTop() {
        selectedViewController?.scrollToTop()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        customView.headerView.layoutIfNeeded()

        let systemBars = UIApplication.useSystemBarsAppearance

        exploreViewController.setListContentInsets(
            UIEdgeInsets(
                top: systemBars ? 0 : customView.headerView.bounds.height,
                left: 0,
                bottom: (systemBars ? 0 : customView.safeAreaInsets.bottom) + customView.searchBar.bounds.height,
                right: 0
            )
        )
        connectedViewController.setListContentInsets(
            UIEdgeInsets(
                top: systemBars ? 0 : customView.headerView.bounds.height,
                left: 0,
                bottom: (systemBars ? 0 : customView.safeAreaInsets.bottom) + customView.searchBar.bounds.height,
                right: 0
            )
        )
    }
}

// MARK: - Private

private extension BrowserViewController {
    func setup() {
        addChild(exploreViewController)
        customView.embedExploreView(exploreViewController.customView)
        exploreViewController.didMove(toParent: self)

        addChild(connectedViewController)
        customView.embedConnectedView(connectedViewController.customView)
        connectedViewController.didMove(toParent: self)

        customView.searchBar.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(
                    didTapSearchBar
                )
            )
        )
    }

    func setupBindings() {
        viewModel.didUpdateSegmentedControl = { [weak self] model in
            self?.customView.headerView.segmentedControlView.configure(model: model)
            self?.setupNavigationBarIfNeeded(isExploreVisible: model.isExploreTabVisible)
        }

        viewModel.didSelectExplore = { [weak self] in
            self?.customView.headerView.segmentedControlView.selectExploreButton()
            self?.showExplore()
        }

        viewModel.didSelectConnected = { [weak self] in
            self?.customView.headerView.segmentedControlView.selectConnectedButton()
            self?.showConnected()
        }

        viewModel.didUpdateRightHeaderButton = { [weak customView] model in
            customView?.headerView.configureRightButton(model: model)
        }
    }

    func showExplore() {
        customView.exploreContainer.isHidden = false
        customView.connectedContainer.isHidden = true
        selectedViewController = exploreViewController
        selectedTab = .explore
    }

    func showConnected() {
        customView.connectedContainer.isHidden = false
        customView.exploreContainer.isHidden = true
        selectedViewController = connectedViewController
        selectedTab = .connected
    }

    @objc
    func didTapSearchBar() {
        viewModel.didTapSearchBar()
    }
}

// MARK: - System Navigation Bar

private extension BrowserViewController {
    enum SelectedTab {
        case explore
        case connected
    }

    func setupNavigationBarIfNeeded(isExploreVisible: Bool) {
        guard UIApplication.useSystemBarsAppearance else {
            return
        }

        if isExploreVisible {
            navigationItem.title = nil
            navigationItem.leftBarButtonItems = [
                exploreButton,
                connectedButton,
            ]

            exploreButton.tintColor = .Accent.blue
            connectedButton.tintColor = .Accent.blue

            exploreButton.setTitleTextAttributes([.font: TKTextStyle.label2.font], for: .normal)
            exploreButton.setTitleTextAttributes([.font: TKTextStyle.label2.font], for: .highlighted)
            connectedButton.setTitleTextAttributes([.font: TKTextStyle.label2.font], for: .normal)
            connectedButton.setTitleTextAttributes([.font: TKTextStyle.label2.font], for: .highlighted)

            updateSelectedButton()
        } else {
            navigationItem.title = TKLocales.Browser.Tab.connected
            navigationItem.leftBarButtonItems = nil
        }
    }

    func updateSelectedButton() {
        if #available(iOS 26.0, *) {
            switch selectedTab {
            case .explore:
                exploreButton.style = .prominent
                connectedButton.style = .plain
            case .connected:
                exploreButton.style = .plain
                connectedButton.style = .prominent
            }
        }
    }

    @objc
    func didTapExploreButton() {
        viewModel.didSelectExplore?()
    }

    @objc
    func didTapConnectedButton() {
        viewModel.didSelectConnected?()
    }
}
