import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class BrowserExploreViewController: GenericViewViewController<BrowserExploreView>, ScrollViewController {
    private let featuredView = BrowserExploreFeaturedView()
    private lazy var dataSource: BrowserExplore.DataSource = createDataSource()
    lazy var layout = createLayout()

    private let refreshControl = UIRefreshControl()

    private let viewModel: BrowserExploreViewModel

    init(viewModel: BrowserExploreViewModel) {
        self.viewModel = viewModel
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

    func scrollToTop() {
        guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
        customView.collectionView.setContentOffset(
            CGPoint(
                x: 0,
                y: -customView.collectionView.adjustedContentInset.top
            ),
            animated: true
        )
    }

    func setListContentInsets(_ insets: UIEdgeInsets) {
        customView.topInset = insets.top
        customView.collectionView.contentInset = insets
    }
}

extension BrowserExploreViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let item = dataSource
            .snapshot()
            .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
        switch item {
        case let .app(appItem):
            appItem.selectionHandler?()
        default:
            break
        }
    }
}

// MARK: - Private

private extension BrowserExploreViewController {
    func setup() {
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.register(
            TKContainerCollectionViewCell.self,
            forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
        )

        refreshControl.addAction(UIAction(handler: { [weak self] _ in
            self?.viewModel.reload()
        }), for: .valueChanged)

        featuredView.didSelectApp = { [weak self] dapp in
            self?.viewModel.selectFeaturedApp(dapp: dapp)
        }
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            if #available(iOS 15.0, *) {
                self?.dataSource.applySnapshotUsingReloadData(snapshot)
            } else {
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            self?.refreshControl.endRefreshing()
        }

        viewModel.didUpdateFeaturedItems = { [weak self] dapps in
            if dapps.isEmpty {
                self?.featuredView.isHidden = false
            } else {
                self?.featuredView.isHidden = false
                self?.featuredView.dapps = dapps
            }
        }

        viewModel.didUpdateIsRefreshEnable = { [weak self] isEnable in
            guard let self else { return }
            customView.collectionView.refreshControl = isEnable ? refreshControl : nil
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: {
            [weak self] sectionIndex, _ -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }

            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            switch section {
            case let .apps(_, header, twoLinesAppsTitle):
                return BrowserCollectionLayout.appsSectionLayout(
                    hasSectionTitle: header != nil,
                    twoLinesAppsTitle: twoLinesAppsTitle
                )
            case .featured:
                return createFeaturedSectionLayout()
            case .ads:
                return createAdsSectionLayout()
            }
        }, configuration: configuration)
    }

    func createFeaturedSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.46)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(50)
        )

        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 16, trailing: 0)
        return section
    }

    func createAdsSectionLayout() -> NSCollectionLayoutSection {
        let sectionLayout: NSCollectionLayoutSection = .listItemsSection
        sectionLayout.contentInsets.bottom = 16
        sectionLayout.contentInsets.leading = 16
        sectionLayout.contentInsets.trailing = 16

        return sectionLayout
    }

    func createDataSource() -> BrowserExplore.DataSource {
        let connectedAppCellConfiguration = UICollectionView.CellRegistration<BrowserAppCollectionViewCell, BrowserAppCollectionViewCell.Configuration> { cell, _, itemIdentifier in
            cell.configure(configuration: itemIdentifier)
        }
        let listItemCellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        let dataSource = BrowserExplore.DataSource(collectionView: customView.collectionView) {
            [weak self] collectionView, indexPath, itemIdentifier in
            guard let self else { return UICollectionViewCell() }
            switch itemIdentifier {
            case let .app(appItem):
                let cell = collectionView.dequeueConfiguredReusableCell(
                    using: connectedAppCellConfiguration,
                    for: indexPath,
                    item: appItem.configuration
                )
                cell.didLongPress = {
                    appItem.longPressHandler?()
                }
                return cell
            case .featured:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                (cell as? TKContainerCollectionViewCell)?.setContentView(featuredView)
                return cell
            case let .ads(adsItem):
                let cell = collectionView.dequeueConfiguredReusableCell(
                    using: listItemCellConfiguration,
                    for: indexPath,
                    item: adsItem.configuration
                )
                cell.isHiglightable = false

                if let buttonAccessory = adsItem.buttonAccessory {
                    let accessoryButton = TKListItemButtonAccessoryView()
                    accessoryButton.configuration = buttonAccessory
                    cell.defaultAccessoryViews = [accessoryButton]
                } else {
                    cell.defaultAccessoryViews = []
                }

                return cell
            }
        }

        let sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<BrowserExploreSectionHeaderView>(
            elementKind: BrowserExploreSectionHeaderView.reuseIdentifier
        ) { _, _, _ in }
        dataSource.supplementaryViewProvider = {
            collectionView, _, indexPath in
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case let .apps(_, header, _):
                guard let header = header else { return nil }
                let headerView = collectionView.dequeueConfiguredReusableSupplementary(
                    using: sectionHeaderRegistration,
                    for: indexPath
                )

                headerView.configure(
                    model: BrowserExploreSectionHeaderView.Model(
                        title: header.title,
                        isAllHidden: !header.hasAll,
                        allTapAction: {
                            header.allTapHandler?()
                        }
                    )
                )
                return headerView
            default:
                return nil
            }
        }
        return dataSource
    }
}
