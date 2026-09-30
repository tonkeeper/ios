import TKCoordinator
import TKUIKit
import UIKit

final class HistoryListViewController: GenericViewViewController<HistoryListView> {
    typealias EventCellConfiguration = UICollectionView.CellRegistration<HistoryCell, HistoryList.EventID>
    typealias PaginationCellConfiguration = UICollectionView.CellRegistration<HistoryListPaginationCell, HistoryListPaginationCell.Model>
    typealias ShimmerCellConfiguration = UICollectionView.CellRegistration<HistoryListShimmerCell, HistoryListShimmerCell.Model>
    typealias ContainerViewConfiguration = UICollectionView.SupplementaryRegistration<TKReusableContainerView>
    typealias EventSectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
    typealias EventSectionHeaderConfiguration = UICollectionView.SupplementaryRegistration<EventSectionHeaderView>

    var didScroll: ((_ scrollView: UIScrollView) -> Void)?
    var didPullToRefresh: (() -> Void)?

    private lazy var dataSource = setupDataSource()
    private lazy var layout = setupLayout()

    private var headerViewController: UIViewController?
    enum EmptyState {
        case view(UIView)
        case viewController(UIViewController)
    }

    private weak var emptyViewController: UIViewController?
    private var emptyViewProvider: ((HistoryList.Filter) -> EmptyState?)?

    private let viewModel: HistoryListViewModel

    init(
        viewModel: HistoryListViewModel,
        emptyViewProvider: ((HistoryList.Filter) -> EmptyState?)?
    ) {
        self.viewModel = viewModel
        self.emptyViewProvider = emptyViewProvider
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        subscribeAppStateNotifications()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unsubscribeAppStateNotifications()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        triggerPaginationIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        customView.collectionView.contentInset.bottom = view.safeAreaInsets.bottom
    }

    func setHeaderViewController(_ headerViewController: UIViewController?) {
        self.headerViewController?.willMove(toParent: nil)
        self.headerViewController?.removeFromParent()
        self.headerViewController?.didMove(toParent: nil)
        self.headerViewController = headerViewController
        if let headerViewController = headerViewController {
            addChild(headerViewController)
        }
        headerViewController?.didMove(toParent: self)
        customView.collectionView.reloadData()
    }

    func scrollToTop() {
        scrollToTop(animated: true)
    }

    func scrollToTop(animated: Bool) {
        guard customView.collectionView.realYOffset > 0 else { return }
        customView.collectionView.setContentOffset(
            CGPoint(
                x: 0,
                y: -customView.collectionView.adjustedContentInset.top
            ),
            animated: animated
        )
    }

    var contentTopPadding: CGFloat {
        get {
            _contentTopPadding
        }
        set {
            customView.collectionView.contentInset.top = newValue
            if newValue != _contentTopPadding {
                scrollToTop(animated: false)
            }
            _contentTopPadding = newValue
        }
    }

    private var _contentTopPadding: CGFloat = 0
}

private extension HistoryListViewController {
    func setup() {
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.register(
            TKContainerCollectionViewCell.self,
            forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
        )

        customView.refreshControl.addAction(UIAction(handler: { [weak self] _ in
            self?.viewModel.reload(force: true)
            self?.didPullToRefresh?()
        }), for: .valueChanged)

        setupBindings()
    }

    func setupBindings() {
        viewModel.snapshotUpdate = { [weak self] snapshot in
            guard let self else { return }
            customView.refreshControl.endRefreshing()
            dataSource.applySnapshotUsingReloadData(snapshot) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }

                    triggerPaginationIfNeeded()
                }
            }
        }

        viewModel.scrollToTop = { [weak self] animated in
            self?.scrollToTop(animated: animated)
        }
    }

    func setupLayout() -> UICollectionViewCompositionalLayout {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(0)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: .headerElementKind,
            alignment: .top
        )

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        configuration.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(
            sectionProvider: { [dataSource] sectionIndex, _ in
                let snapshot = dataSource.snapshot()
                switch snapshot.sectionIdentifiers[sectionIndex] {
                case .events:
                    return .eventsSection
                case .pagination:
                    return .paginationSection
                case .shimmer:
                    return .shimmerSection
                case .empty:
                    return .emptySection()
                }
            },
            configuration: configuration
        )
    }

    func setupDataSource() -> HistoryList.DataSource {
        let eventCellConfiguration = EventCellConfiguration {
            [weak viewModel] cell, _, itemIdentifier in
            guard let model = viewModel?.getEventCellConfiguration(eventID: itemIdentifier) else { return }
            cell.configure(model: model)
        }

        let paginationCellConfiguration = PaginationCellConfiguration {
            cell, _, itemIdentifier in
            cell.configure(model: itemIdentifier)
        }

        let shimmerCellConfiguration = ShimmerCellConfiguration {
            cell, _, itemIdentifier in
            cell.configure(model: itemIdentifier)
        }

        let dataSource = HistoryList.DataSource(collectionView: customView.collectionView) { [weak self]
            collectionView, indexPath, itemIdentifier in
                guard let self else { return nil }
                switch itemIdentifier {
                case let .event(eventId):
                    return collectionView.dequeueConfiguredReusableCell(
                        using: eventCellConfiguration,
                        for: indexPath,
                        item: eventId
                    )
                case .pagination:
                    return collectionView.dequeueConfiguredReusableCell(
                        using: paginationCellConfiguration,
                        for: indexPath,
                        item: viewModel.getPaginationCellConfiguration()
                    )
                case .shimmer:
                    return collectionView.dequeueConfiguredReusableCell(
                        using: shimmerCellConfiguration,
                        for: indexPath,
                        item: HistoryListShimmerCell.Model()
                    )
                case .empty:
                    let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                        for: indexPath
                    )
                    emptyViewController?.willMove(toParent: nil)
                    emptyViewController?.view.removeFromSuperview()
                    emptyViewController?.removeFromParent()
                    let height = collectionView.bounds.height - collectionView.adjustedContentInset.top - collectionView.adjustedContentInset.bottom
                    guard let emptyState = emptyViewProvider?(viewModel.filter) else { return cell }
                    switch emptyState {
                    case let .view(view):
                        (cell as? TKContainerCollectionViewCell)?.setContentView(view)
                        view.snp.makeConstraints { make in
                            make.height.equalTo(height)
                        }
                    case let .viewController(viewController):
                        addChild(viewController)
                        (cell as? TKContainerCollectionViewCell)?.setContentView(viewController.view)
                        viewController.didMove(toParent: self)
                        viewController.view.snp.makeConstraints { make in
                            make.height.equalTo(height)
                        }
                        emptyViewController = viewController
                    }
                    return cell
                }
        }

        let containerViewConfiguration = ContainerViewConfiguration(elementKind: .headerElementKind) { [weak self] supplementaryView, _, _ in
            supplementaryView.setContentView(self?.headerViewController?.view)
        }

        let eventSectionHeaderConfiguration = EventSectionHeaderConfiguration(elementKind: .eventSectionHeaderElementKind) {
            [weak dataSource, weak viewModel] supplementaryView, _, indexPath in
            guard let dataSource else { return }
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            switch section {
            case let .events(eventsSection):
                supplementaryView.configure(
                    model: TKListTitleView.Model(
                        title: viewModel?.getSectionHeaderTitle(sectionID: eventsSection),
                        textStyle: .label1
                    )
                )
            case .pagination, .shimmer, .empty:
                return
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
            switch kind {
            case .headerElementKind:
                return collectionView.dequeueConfiguredReusableSupplementary(using: containerViewConfiguration, for: indexPath)
            case .eventSectionHeaderElementKind:
                return collectionView.dequeueConfiguredReusableSupplementary(using: eventSectionHeaderConfiguration, for: indexPath)
            default:
                return nil
            }
        }

        return dataSource
    }

    func subscribeAppStateNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func unsubscribeAppStateNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc
    func didBecomeActive() {
        viewModel.reload(force: false)
    }

    func triggerPaginationIfNeeded() {
        guard case .loading = viewModel.getPaginationCellConfiguration().state else {
            return
        }
        guard let paginationIndexPath = paginationIndexPath else { return }
        guard shouldTriggerPagination(for: paginationIndexPath) else { return }
        viewModel.loadNextPage()
    }

    var paginationIndexPath: IndexPath? {
        let snapshot = dataSource.snapshot()
        guard let paginationSectionIndex = snapshot.sectionIdentifiers.firstIndex(of: .pagination) else {
            return nil
        }
        let paginationItems = snapshot.itemIdentifiers(inSection: .pagination)
        guard !paginationItems.isEmpty else { return nil }
        return IndexPath(item: paginationItems.count - 1, section: paginationSectionIndex)
    }

    func shouldTriggerPagination(for indexPath: IndexPath) -> Bool {
        let collectionView = customView.collectionView
        let viewportBottom = collectionView.contentOffset.y + collectionView.bounds.height - collectionView.adjustedContentInset.bottom
        guard let lastCellFrame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
            return false
        }
        let distanceToLastCell = lastCellFrame.minY - viewportBottom
        return distanceToLastCell <= .paginationLoadTriggerThreshold
    }
}

private extension NSCollectionLayoutSection {
    static var eventsSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(48)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: .eventSectionHeaderElementKind,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]

        return section
    }

    static var paginationSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(40)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(40)
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        return NSCollectionLayoutSection(group: group)
    }

    static var shimmerSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        return NSCollectionLayoutSection(group: group)
    }

    static func emptySection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        return NSCollectionLayoutSection(group: group)
    }
}

extension HistoryListViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        (cell as? HistoryListShimmerCell)?.startAnimation()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        (cell as? HistoryListShimmerCell)?.stopAnimation()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?(scrollView)
        triggerPaginationIfNeeded()
    }
}

private extension String {
    static let headerElementKind = "HeaderElementKind"
    static let eventSectionHeaderElementKind = "EventSectionHeaderElementKind"
}

extension UIScrollView {
    var realYOffset: CGFloat {
        max(0, contentOffset.y + adjustedContentInset.top)
    }
}

private extension CGFloat {
    static let paginationLoadTriggerThreshold: CGFloat = 120
}
