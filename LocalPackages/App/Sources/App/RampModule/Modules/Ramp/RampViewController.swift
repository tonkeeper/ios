import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class RampViewController: GenericViewViewController<RampView> {
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias SectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>

    enum Section: Hashable {
        case action
        case fiatCurrency
        case tokensList
        case retryPlaceholder
    }

    enum Item: Hashable {
        case receiveTokens(TKListItemCell.Configuration)
        case sendTokens(TKListItemCell.Configuration)
        case fiatCurrencyPicker(RampFiatCurrencyCell.Model)
        case item(item: OnRampLayoutItem, configuration: RampItemCell.Configuration)
        case shimmer
        case retry
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

    override func viewDidLoad() {
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
            self?.customView.collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    func createDataSource() -> DataSource {
        let shimmerCellRegistration = UICollectionView.CellRegistration<RampShimmerCell, RampShimmerCell.Model> { _, _, _ in }
        let receiveSendCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        let rampItemCellRegistration = RampItemCellRegistration.registration(collectionView: customView.collectionView)
        let retryCellRegistration = RampLoadErrorListCellRegistration.registration(collectionView: customView.collectionView)
        let fiatCurrencyCellRegistration = UICollectionView.CellRegistration<RampFiatCurrencyCell, RampFiatCurrencyCell.Model> { [weak self] cell, _, model in
            cell.configure(model: model)
            cell.didTapCurrencyButton = { [weak self] in
                self?.viewModel.didTapFiatCurrencyPicker()
            }
        }

        return DataSource(collectionView: customView.collectionView) { [weak self] collectionView, indexPath, item in
            switch item {
            case .shimmer:
                return collectionView.dequeueConfiguredReusableCell(using: shimmerCellRegistration, for: indexPath, item: RampShimmerCell.Model())
            case .retry:
                let cell = collectionView.dequeueConfiguredReusableCell(using: retryCellRegistration, for: indexPath, item: ())
                cell.didTapRetry = { [weak self] in
                    self?.viewModel.retry()
                }
                return cell
            case let .receiveTokens(configuration), let .sendTokens(configuration):
                let cell = collectionView.dequeueConfiguredReusableCell(using: receiveSendCellRegistration, for: indexPath, item: configuration)
                cell.defaultAccessoryViews = [TKListItemAccessory.chevron.view]
                return cell
            case let .fiatCurrencyPicker(model):
                return collectionView.dequeueConfiguredReusableCell(using: fiatCurrencyCellRegistration, for: indexPath, item: model)
            case let .item(_, configuration):
                let cell = collectionView.dequeueConfiguredReusableCell(using: rampItemCellRegistration, for: indexPath, item: configuration)
                cell.defaultAccessoryViews = [TKListItemAccessory.chevron.view]
                return cell
            }
        }
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
                return section
            case .fiatCurrency:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(140))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 32, trailing: 16)
                return section
            case .tokensList:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(96))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
                section.interGroupSpacing = 8
                return section
            case .retryPlaceholder:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(80))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                return section
            }
        }
    }
}

extension RampViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let items = snapshot.itemIdentifiers(inSection: section)
        guard indexPath.item < items.count else { return true }
        if case .fiatCurrencyPicker = items[indexPath.item] {
            return false
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RampShimmerCell)?.startAnimation()
        (cell as? RampFiatCurrencyCell)?.resumeCurrencyShimmerIfNeeded()
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RampShimmerCell)?.stopAnimation()
        (cell as? RampFiatCurrencyCell)?.pauseCurrencyShimmer()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let items = snapshot.itemIdentifiers(inSection: section)
        guard indexPath.item < items.count else { return }

        let item = items[indexPath.item]
        if case .shimmer = item { return }
        viewModel.didSelect(item: item)
    }
}
