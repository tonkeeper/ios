import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

public final class RampViewController: GenericViewViewController<RampView> {
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias SectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>

    enum Section: Hashable {
        case action
        case tokensList
    }

    enum Item: Hashable {
        case receiveTokens(TKListItemCell.Configuration)
        case sendTokens(TKListItemCell.Configuration)
        case tokenItem(asset: RampAsset, configuration: RampItemCell.Configuration)
        case shimmer
    }

    private let viewModel: RampViewModel
    private lazy var dataSource = createDataSource()

    init(viewModel: RampViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension RampViewController {
    func setup() {
        setupNavigationBar()
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
    }

    func setupNavigationBar() {
        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.viewModel.didTapCloseButton()
            },
        ]
        customView.navigationBar.didTapNavigationBar = { [weak self] in
            self?.view.endEditing(true)
        }
    }

    func setupBindings() {
        viewModel.didUpdateTitleView = { [weak self] model in
            self?.customView.titleView.configure(model: model)
        }

        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            self?.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    func createDataSource() -> DataSource {
        let shimmerCellRegistration = UICollectionView.CellRegistration<RampShimmerCell, RampShimmerCell.Model> { _, _, _ in }
        let receiveSendCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        let rampItemCellRegistration = RampItemCellRegistration.registration(collectionView: customView.collectionView)

        let sectionHeaderRegistration = SectionHeaderRegistration(elementKind: Self.sectionHeaderElementKind) { [weak self] supplementaryView, _, _ in
            let title = self?.viewModel.sectionHeaderTitle
            supplementaryView.configure(model: TKListTitleView.Model(title: title, textStyle: .label1))
        }
        let dataSource = DataSource(collectionView: customView.collectionView) { collectionView, indexPath, item in
            switch item {
            case .shimmer:
                return collectionView.dequeueConfiguredReusableCell(using: shimmerCellRegistration, for: indexPath, item: RampShimmerCell.Model())
            case let .receiveTokens(configuration), let .sendTokens(configuration):
                let cell = collectionView.dequeueConfiguredReusableCell(using: receiveSendCellRegistration, for: indexPath, item: configuration)
                cell.defaultAccessoryViews = [TKListItemAccessory.chevron.view]
                return cell
            case let .tokenItem(_, configuration):
                return collectionView.dequeueConfiguredReusableCell(using: rampItemCellRegistration, for: indexPath, item: configuration)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case Self.sectionHeaderElementKind:
                return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderRegistration, for: indexPath)
            default:
                return nil
            }
        }
        return dataSource
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            switch section {
            case .action:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(80))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
                return section
            case .tokensList:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(96))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
                section.interGroupSpacing = 0
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(48))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: Self.sectionHeaderElementKind,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
    }
}

extension RampViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RampShimmerCell)?.startAnimation()
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RampShimmerCell)?.stopAnimation()
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let items = snapshot.itemIdentifiers(inSection: section)
        guard indexPath.item < items.count else { return }

        let item = items[indexPath.item]
        if case .shimmer = item { return }
        viewModel.didSelect(item: item)
    }
}

private extension RampViewController {
    static let sectionHeaderElementKind = "RampSectionHeaderElementKind"
}
