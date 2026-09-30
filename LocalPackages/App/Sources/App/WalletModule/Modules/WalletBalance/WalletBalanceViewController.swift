import TKCoordinator
import TKCore
import TKUIKit
import UIKit

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView>, ScrollViewController, WalletContainerBalanceViewController {
    var didScroll: ((CGFloat) -> Void)?

    private let viewModel: WalletBalanceViewModel
    private let tooltipsService: TooltipsService
    private let homeBannersContainerView = WalletBalanceHomeBannersContainerView()
    private let collectiblesContainerView = WalletBalanceCollectiblesContainerView()
    private let cryptoAssetsHeaderContainerView = WalletBalanceCryptoAssetsSectionHeaderContainerView()
    init(
        viewModel: WalletBalanceViewModel,
        tooltipsService: TooltipsService
    ) {
        self.viewModel = viewModel
        self.tooltipsService = tooltipsService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletBalanceView(tooltipsService: tooltipsService)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        configureHomeBannersIfNeeded()
        configureCollectiblesIfNeeded()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.viewDidDisappear()
    }

    func scrollToTop() {
        scrollToTop(animated: true)
    }

    func setup() {
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.showsVerticalScrollIndicator = false
        customView.collectionView.register(
            TKContainerCollectionViewCell.self,
            forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
        )
        customView.refreshControl.addAction(UIAction(handler: { [weak self] _ in
            self?.viewModel.reloadData()
        }), for: .valueChanged)
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot, isAnimated in
            guard let self else { return }
            customView.refreshControl.endRefreshing()
            // Reloading data recreates hosted SwiftUI sections and makes the banner deck blink.
            dataSource.apply(snapshot, animatingDifferences: isAnimated)
        }

        viewModel.didUpdateHeader = { [weak self] model in
            guard let self else { return }
            customView.headerView.configure(model: model)
        }
        viewModel.didChangeWallet = { [weak self] in
            self?.scrollToTop(animated: false)
        }
        viewModel.didUpdateItems = { [weak self] items in
            guard let self else { return }
            for item in items {
                guard let indexPath = self.dataSource.indexPath(for: .listItem(item.key)),
                      let cell = self.customView.collectionView.cellForItem(at: indexPath) as? WalletBalanceListCell
                else {
                    continue
                }
                cell.configuration = item.value
            }
        }
        viewModel.didCopy = { configuration in
            ToastPresenter.showToast(configuration: configuration)
        }
        viewModel.didChangeHostedViewModels = { [weak self] in
            guard let self else { return }
            configureHomeBannersIfNeeded()
            configureCollectiblesIfNeeded()
        }
    }

    private lazy var dataSource: WalletBalance.DataSource = {
        let balanceListCellRegistration = WalletBalanceListCellRegistration.registration(collectionView: customView.collectionView)
        let moreAssetsListCellRegistration = WalletBalanceMoreAssetsListCellRegistration.registration(
            collectionView: customView.collectionView
        )
        let notifiationCellRegistration = NotificationBannerCellRegistration.registration

        let dataSource = WalletBalance.DataSource(
            collectionView: customView.collectionView
        ) {
            [weak self] collectionView, indexPath, itemIdentifier in
            guard let self else { return nil }
            switch itemIdentifier {
            case .balanceHeader:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                (cell as? TKContainerCollectionViewCell)?.setContentView(customView.headerView)
                return cell
            case let .listItem(listItem):
                let configuration = self.viewModel.getListItemCellConfiguration(identifier: listItem.identifier) ?? .default
                let cell = collectionView.dequeueConfiguredReusableCell(
                    using: balanceListCellRegistration,
                    for: indexPath,
                    item: configuration
                )
                if let accessoryView = listItem.accessory?.view {
                    cell.defaultAccessoryViews = [accessoryView]
                } else {
                    cell.defaultAccessoryViews = []
                }
                return cell
            case let .notificationItem(notificationItem):
                let configuration = self.viewModel.getNotificationItemCellConfiguration(identifier: notificationItem.id) ?? .default
                return collectionView.dequeueConfiguredReusableCell(
                    using: notifiationCellRegistration,
                    for: indexPath,
                    item: configuration
                )
            case .collectibles:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                (cell as? TKContainerCollectionViewCell)?.setContentView(self.collectiblesContainerView)
                return cell
            case .banners:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                (cell as? TKContainerCollectionViewCell)?.setContentView(self.homeBannersContainerView)
                return cell
            case .cryptoAssetsHeader:
                guard let section = self.dataSource.sectionIdentifier(for: indexPath.section),
                      case let .cryptoAssetsHeader(canManage) = section
                else {
                    return nil
                }
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                self.cryptoAssetsHeaderContainerView.configure(
                    canManage: canManage,
                    onTapOpenAssets: { [weak self] in
                        self?.viewModel.tapCryptoAssetsOpen()
                    },
                    onTapManage: { [weak self] in
                        self?.viewModel.tapCryptoAssetsManage()
                    }
                )
                (cell as? TKContainerCollectionViewCell)?.setContentView(self.cryptoAssetsHeaderContainerView)
                return cell
            case .moreAssets:
                let cell = collectionView.dequeueConfiguredReusableCell(
                    using: moreAssetsListCellRegistration,
                    for: indexPath,
                    item: ()
                )
                cell.configure(previewAvatars: self.viewModel.moreAssetsPreviewAvatars)
                return cell
            }
        }

        let listButtonHeaderRegistration = TKListCollectionViewButtonHeaderViewRegistration.registration()
        dataSource.supplementaryViewProvider = { [weak self] collectionView, elementKind, indexPath in
            if elementKind == String.balanceHeaderElementKind {
                let view = collectionView.dequeueReusableSupplementaryView(
                    ofKind: elementKind,
                    withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
                    for: indexPath
                ) as? TKReusableContainerView
                view?.setContentView(self?.customView.headerView)
                return view
            }

            switch elementKind {
            case TKListCollectionViewButtonHeaderView.elementKind:
                guard let snapshotSection = self?.dataSource.sectionIdentifier(for: indexPath.section) else {
                    return nil
                }
                switch snapshotSection {
                case let .setup(setupSection):
                    let view = collectionView.dequeueConfiguredReusableSupplementary(
                        using: listButtonHeaderRegistration,
                        for: indexPath
                    )
                    view.configuration = setupSection.headerConfiguration
                    return view
                default: return nil
                }
            default: return nil
            }
        }

        return dataSource
    }()
}

private extension WalletBalanceViewController {
    func scrollToTop(animated: Bool = true) {
        guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
        customView.collectionView.setContentOffset(
            CGPoint(
                x: 0,
                y: -customView.collectionView.adjustedContentInset.top
            ),
            animated: animated
        )
    }

    /// A zero absolute dimension is logged as invalid by the layout, which says it will assert.
    static func sectionHeight(_ height: CGFloat) -> CGFloat {
        max(height, Layout.emptySectionHeight)
    }

    private var layout: UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(
            sectionProvider: { [weak dataSource, weak viewModel] sectionIndex, _ in
                guard let dataSource,
                      let snapshotSection = dataSource.sectionIdentifier(for: sectionIndex)
                else {
                    return nil
                }

                switch snapshotSection {
                case .balanceHeader:
                    let itemLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(221)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

                    let groupLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(221)
                    )
                    let group = NSCollectionLayoutGroup.horizontal(
                        layoutSize: groupLayoutSize,
                        subitems: [item]
                    )

                    let layoutSection = NSCollectionLayoutSection(group: group)
                    layoutSection.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 16,
                        bottom: 0,
                        trailing: 16
                    )
                    return layoutSection
                case .cryptoAssetsHeader:
                    let itemLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(44)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
                    let group = NSCollectionLayoutGroup.horizontal(
                        layoutSize: itemLayoutSize,
                        subitems: [item]
                    )
                    let layoutSection = NSCollectionLayoutSection(group: group)
                    layoutSection.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 16,
                        bottom: 0,
                        trailing: 16
                    )
                    return layoutSection
                case .balance:
                    let sectionLayout: NSCollectionLayoutSection = .listItemsSection
                    sectionLayout.contentInsets.bottom = 16
                    return sectionLayout
                case .setup:
                    let sectionLayout: NSCollectionLayoutSection = .listItemsSection
                    sectionLayout.contentInsets.bottom = 16

                    let headerSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(100)
                    )
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: headerSize,
                        elementKind: TKListCollectionViewButtonHeaderView.elementKind,
                        alignment: .top
                    )
                    sectionLayout.boundarySupplementaryItems.append(header)

                    return sectionLayout
                case .notifications:
                    let sectionLayout: NSCollectionLayoutSection = .listItemsSection
                    sectionLayout.interGroupSpacing = 16
                    sectionLayout.contentInsets.bottom = 16
                    return sectionLayout
                case .banners:
                    let itemLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(
                            Self.sectionHeight(
                                viewModel?.homeBannersViewModel.sectionHeight
                                    ?? WalletBalanceHomeBannersLayout.expandedHeight
                            )
                        )
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
                    let group = NSCollectionLayoutGroup.horizontal(
                        layoutSize: itemLayoutSize,
                        subitems: [item]
                    )
                    let layoutSection = NSCollectionLayoutSection(group: group)
                    layoutSection.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                    return layoutSection
                case .collectibles:
                    let itemLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(
                            Self.sectionHeight(viewModel?.collectiblesViewModel.sectionContentHeight ?? 0)
                        )
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
                    let group = NSCollectionLayoutGroup.horizontal(
                        layoutSize: itemLayoutSize,
                        subitems: [item]
                    )
                    let layoutSection = NSCollectionLayoutSection(group: group)
                    layoutSection.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: viewModel?.collectiblesViewModel.isSectionVisible == true ? 16 : 0,
                        trailing: 0
                    )
                    return layoutSection
                }
            },
            configuration: configuration
        )
    }

    func configureHomeBannersIfNeeded() {
        let homeBannersViewModel = viewModel.homeBannersViewModel
        homeBannersViewModel.onSectionHeightChanged = { [weak self, weak homeBannersViewModel] _ in
            guard let self, let homeBannersViewModel,
                  homeBannersViewModel === viewModel.homeBannersViewModel else { return }
            invalidateHomeBannersLayout()
        }
        homeBannersContainerView.configure(viewModel: homeBannersViewModel)
        invalidateHomeBannersLayout(animated: false)
    }

    func configureCollectiblesIfNeeded() {
        let collectiblesViewModel = viewModel.collectiblesViewModel
        collectiblesViewModel.onContentHeightChanged = { [weak self, weak collectiblesViewModel] in
            guard let self, let collectiblesViewModel,
                  collectiblesViewModel === viewModel.collectiblesViewModel else { return }
            invalidateCollectiblesLayout()
        }
        collectiblesContainerView.configure(viewModel: collectiblesViewModel)
        invalidateCollectiblesLayout(animated: false)
    }

    func invalidateHomeBannersLayout(animated: Bool = true) {
        let snapshot = dataSource.snapshot()
        guard snapshot.itemIdentifiers.contains(.banners) else { return }

        guard animated else {
            customView.collectionView.collectionViewLayout.invalidateLayout()
            return
        }

        UIView.animate(
            withDuration: WalletBalanceHomeBannersLayout.animationDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.customView.collectionView.collectionViewLayout.invalidateLayout()
            self.customView.collectionView.layoutIfNeeded()
        }
    }

    func invalidateCollectiblesLayout(animated: Bool = true) {
        let snapshot = dataSource.snapshot()
        guard snapshot.itemIdentifiers.contains(.collectibles) else { return }

        guard animated else {
            customView.collectionView.collectionViewLayout.invalidateLayout()
            return
        }

        UIView.animate(
            withDuration: WalletBalanceCollectiblesLayout.animationDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.customView.collectionView.collectionViewLayout.invalidateLayout()
            self.customView.collectionView.layoutIfNeeded()
        }
    }
}

extension WalletBalanceViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case let .listItem(listItem):
            listItem.onSelection?()
        case .moreAssets:
            viewModel.expandMoreAssets()
        default:
            return
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
    }
}

private extension WalletBalanceViewController {
    enum Layout {
        static let emptySectionHeight: CGFloat = 1
    }
}

private extension String {
    static let balanceHeaderElementKind = "BalanceHeaderElementKind"
}
