import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class PaymentMethodViewController: GenericViewViewController<PaymentMethodView> {
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias CashHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<CashSectionHeaderView>>
    typealias CryptoHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<CryptoSectionHeaderView>>

    enum Section: Hashable {
        case shimmer(Int)
        case cashMethods(String)
        case convertFromCrypto(title: String)
        case convertFromStablecoins(title: String, subtitle: String?)
    }

    enum Item: Hashable {
        case shimmer(sectionIndex: Int)
        case cashMethod(OnRampLayoutCashMethod)
        case cryptoAsset(OnRampLayoutCryptoMethod)
        case allMethods(first: OnRampLayoutCashMethod, second: OnRampLayoutCashMethod)
        case allAssets(first: OnRampLayoutCryptoMethod, second: OnRampLayoutCryptoMethod)
        case stablecoin(symbol: String, image: String?, networkMethods: [OnRampLayoutCryptoMethod])
    }

    private let viewModel: PaymentMethodViewModelProtocol
    private lazy var dataSource = createDataSource()

    init(viewModel: PaymentMethodViewModelProtocol) {
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

private extension PaymentMethodViewController {
    func setup() {
        setupNavigationBar()
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
    }

    func setupNavigationBar() {
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton { [weak self] in
                self?.viewModel.didTapBackButton()
            },
        ]
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

        viewModel.didShowError = { message in
            ToastPresenter.showToast(configuration: .init(title: message))
        }
    }

    func createDataSource() -> DataSource {
        let shimmerCellRegistration = UICollectionView.CellRegistration<RampShimmerCell, RampShimmerCell.Model> { _, _, _ in }

        let iconWithBadgeCellRegistration = UICollectionView.CellRegistration<PaymentMethodAllItemsCell, Item> { [weak self] cell, _, item in
            guard let self, let configuration = PaymentMethodModule.mapAllItemsConfiguration(item: item) else { return }
            cell.configuration = configuration
            let collectionView = self.customView.collectionView
            cell.isFirstInSection = { $0.item == 0 }
            cell.isLastInSection = { $0.item == collectionView.numberOfItems(inSection: $0.section) - 1 }
        }

        let stablecoinCellRegistration = UICollectionView.CellRegistration<PaymentMethodStablecoinCell, Item> { [weak self] cell, _, item in
            guard let self, let configuration = PaymentMethodModule.mapStablecoinItemConfiguration(item: item) else { return }
            let collectionView = self.customView.collectionView
            cell.configuration = configuration
            cell.isFirstInSection = { $0.item == 0 }
            cell.isLastInSection = { $0.item == collectionView.numberOfItems(inSection: $0.section) - 1 }
        }

        let cellRegistration = UICollectionView.CellRegistration<TKListItemCell, Item> { [weak self] cell, _, item in
            guard let self, let configuration = PaymentMethodModule.mapItemConfiguration(item: item) else { return }

            let collectionView = self.customView.collectionView
            cell.configuration = configuration
            cell.defaultAccessoryViews = self.accessoryViews(for: item)
            cell.isFirstInSection = { $0.item == 0 }
            cell.isLastInSection = { $0.item == collectionView.numberOfItems(inSection: $0.section) - 1 }
        }

        let cryptoHeaderRegistration = CryptoHeaderRegistration(elementKind: Self.sectionHeaderElementKind) { [weak self] supplementaryView, _, indexPath in
            guard let self else { return }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            let title: String
            let subtitle: String?
            switch section {
            case let .convertFromCrypto(sectionTitle):
                title = sectionTitle
                subtitle = nil
            case let .convertFromStablecoins(sectionTitle, sectionSubtitle):
                title = sectionTitle
                subtitle = sectionSubtitle
            default:
                return
            }
            supplementaryView.configure(
                model: CryptoSectionHeaderView.Model(
                    title: title,
                    subtitle: subtitle,
                    padding: .init(top: 12, left: 0, bottom: 12, right: 0)
                )
            )
        }

        let cashHeaderRegistration = CashHeaderRegistration(elementKind: Self.sectionHeaderElementKind) { [weak self] supplementaryView, _, indexPath in
            guard let self else { return }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            if case let .cashMethods(title) = section {
                supplementaryView.configure(
                    model: CashSectionHeaderView.Model(
                        title: title,
                        currencyCode: viewModel.currentCurrency?.code,
                        currencyImage: URL(string: viewModel.currentCurrency?.image ?? ""),
                        padding: .init(top: 12, left: 0, bottom: 12, right: 0)
                    )
                )
                supplementaryView.contentView.didTapCurrencyButton = { [weak self] in
                    self?.viewModel.didTapCurrencyButton()
                }
            }
        }

        let dataSource = DataSource(collectionView: customView.collectionView) { collectionView, indexPath, item in
            if case .shimmer = item {
                return collectionView.dequeueConfiguredReusableCell(using: shimmerCellRegistration, for: indexPath, item: RampShimmerCell.Model())
            }
            if PaymentMethodModule.mapAllItemsConfiguration(item: item) != nil {
                return collectionView.dequeueConfiguredReusableCell(using: iconWithBadgeCellRegistration, for: indexPath, item: item)
            }
            if PaymentMethodModule.mapStablecoinItemConfiguration(item: item) != nil {
                return collectionView.dequeueConfiguredReusableCell(using: stablecoinCellRegistration, for: indexPath, item: item)
            }
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == Self.sectionHeaderElementKind, let self else { return nil }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            switch section {
            case .cashMethods:
                return collectionView.dequeueConfiguredReusableSupplementary(using: cashHeaderRegistration, for: indexPath)
            case .convertFromStablecoins, .convertFromCrypto:
                return collectionView.dequeueConfiguredReusableSupplementary(using: cryptoHeaderRegistration, for: indexPath)
            case .shimmer:
                return nil
            }
        }
        return dataSource
    }

    func accessoryViews(for item: Item) -> [UIView] {
        switch item {
        case .allMethods, .allAssets:
            return [TKListItemAccessory.chevron.view]
        case .shimmer, .cashMethod, .cryptoAsset, .stablecoin:
            return []
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            if case .shimmer = section {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(288))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
                return layoutSection
            }
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(72))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
            layoutSection.interGroupSpacing = 0

            let heightDimension: NSCollectionLayoutDimension
            switch section {
            case .cashMethods, .convertFromCrypto(_), .shimmer:
                heightDimension = .estimated(48)
            case let .convertFromStablecoins(_, subtitle):
                heightDimension = .estimated(subtitle?.isEmpty == false ? 72 : 48)
            }

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: heightDimension)
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: Self.sectionHeaderElementKind,
                alignment: .top
            )
            layoutSection.boundarySupplementaryItems = [header]
            return layoutSection
        }
    }
}

extension PaymentMethodViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RampShimmerCell)?.startAnimation()
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? RampShimmerCell)?.stopAnimation()
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

private extension PaymentMethodViewController {
    static let sectionHeaderElementKind = "PaymentMethodSectionHeaderElementKind"
}
