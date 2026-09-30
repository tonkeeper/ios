import TKCore
import TKUIKit
import UIKit

final class WalletsListViewController: GenericViewViewController<WalletsListView>, TKBottomSheetScrollContentViewController {
    typealias Section = WalletsListSection
    typealias Item = WalletsListItem
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    private let viewModel: WalletsListViewModel
    private let tooltipsService: TooltipsService?
    private let shouldShowAddMultichainWalletTooltip: Bool
    private let raffleBannerContainerView = WalletsListRaffleBannerContainerView()
    private var didAttemptAddMultichainWalletTooltip = false

    init(
        viewModel: WalletsListViewModel,
        tooltipsService: TooltipsService? = nil,
        shouldShowAddMultichainWalletTooltip: Bool = false
    ) {
        self.viewModel = viewModel
        self.tooltipsService = tooltipsService
        self.shouldShowAddMultichainWalletTooltip = shouldShowAddMultichainWalletTooltip
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

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        customView.collectionView
    }

    var didUpdateHeight: (() -> Void)?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?
    var headerConfiguration: TKBottomSheetHeaderConfiguration?
    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        scrollView.contentSize.height
    }

    private func setup() {
        customView.collectionView.collectionViewLayout = layout
        customView.collectionView.delegate = self
        customView.collectionView.register(
            TKContainerCollectionViewCell.self,
            forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
        )
    }

    private func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            guard let self else { return }
            let contentOffset = self.customView.collectionView.contentOffset
            self.dataSource.apply(snapshot, animatingDifferences: false, completion: { [weak self] in
                guard let self else { return }
                self.didUpdateHeight?()
                self.selectWallet()
                self.restoreContentOffset(contentOffset)
                self.showAddMultichainWalletTooltipIfNeeded()
            })
        }

        viewModel.didUpdateWaletCellConfiguration = { [weak self] item, configuration in
            guard let indexPath = self?.dataSource.indexPath(for: item),
                  let cell = self?.customView.collectionView.cellForItem(at: indexPath) as? TKListItemCell
            else {
                return
            }
            cell.configuration = configuration
        }

        viewModel.didUpdateHeaderConfiguration = { [weak self] headerConfiguration in
            guard let self else { return }
            let contentOffset = self.customView.collectionView.contentOffset
            self.headerConfiguration = headerConfiguration
            self.didUpdateHeaderConfiguration?(headerConfiguration)
            self.restoreContentOffset(contentOffset)
        }

        viewModel.didUpdateIsEditing = { [weak self] isEditing in
            UIView.animate(withDuration: 0.2) {
                self?.customView.collectionView.isEditing = isEditing
            }
            if isEditing {
                HintController.dismiss()
            } else {
                self?.selectWallet()
            }
        }
    }

    private lazy var dataSource: DataSource = {
        let listItemCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)

        let dataSource = DataSource(
            collectionView: customView.collectionView
        ) {
            [weak self] collectionView, indexPath, itemIdentifier in
            guard let self else { return nil }

            let snapshotSection = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            if case let .raffleBanner(raffleId) = snapshotSection {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                if let raffleBanner = self.viewModel.getRaffleBanner(), raffleBanner.id == raffleId {
                    self.raffleBannerContainerView.configure(
                        banner: raffleBanner,
                        onTap: { [weak self] in self?.viewModel.tapRaffleBanner() },
                        onDismiss: { [weak self] in self?.viewModel.dismissRaffleBanner() }
                    )
                }
                (cell as? TKContainerCollectionViewCell)?.setContentView(self.raffleBannerContainerView)
                return cell
            }

            guard let cellConfiguration = self.viewModel.getWalletCellConfiguration(
                identifier: itemIdentifier.identifier
            ) else { return nil }
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: listItemCellRegistration,
                for: indexPath,
                item: cellConfiguration
            )
            cell.selectionAccessoryViews = itemIdentifier.selectAccessories.map { $0.view }
            cell.editingAccessoryViews = itemIdentifier.editingAccessories.map { $0.view } + [self.makeReorderHandle()]
            return cell
        }

        let listButtonFooterRegistration = TKListCollectionViewButtonFooterViewRegistration.registration()
        dataSource.supplementaryViewProvider = { [weak self] collectionView, elementKind, indexPath in
            guard let snapshot = self?.dataSource.snapshot() else { return nil }
            let snapshotSection = snapshot.sectionIdentifiers[indexPath.section]
            switch elementKind {
            case TKListCollectionViewButtonFooterView.elementKind:
                switch snapshotSection {
                case let .wallets(footerConfiguration):
                    let view = collectionView.dequeueConfiguredReusableSupplementary(
                        using: listButtonFooterRegistration,
                        for: indexPath
                    )
                    view.configuration = footerConfiguration
                    return view
                case .raffleBanner:
                    return nil
                }
            default:
                return nil
            }
        }

        dataSource.reorderingHandlers.canReorderItem = { item in
            !item.isRaffleBanner
        }

        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            self?.didReorder(transaction: transaction)
        }
        return dataSource
    }()

    private var layout: UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(
            sectionProvider: { [weak dataSource] sectionIndex, _ in
                guard let dataSource else { return nil }
                let snapshotSection = dataSource.snapshot().sectionIdentifiers[sectionIndex]

                switch snapshotSection {
                case .wallets:
                    let sectionLayout: NSCollectionLayoutSection = .listItemsSection
                    let footerSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(100)
                    )
                    let footer = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: footerSize,
                        elementKind: TKListCollectionViewButtonFooterView.elementKind,
                        alignment: .bottom
                    )
                    sectionLayout.boundarySupplementaryItems.append(footer)
                    return sectionLayout
                case .raffleBanner:
                    let itemLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(Layout.raffleBannerHeight)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemLayoutSize, subitems: [item])
                    return NSCollectionLayoutSection(group: group)
                }
            },
            configuration: configuration
        )
    }

    private func makeReorderHandle() -> UIView {
        let handle = TKListItemIconAccessoryView()
        handle.configuration = TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.reorder,
            tintColor: .Icon.secondary
        )
        let gesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleReorderGesture(gesture:))
        )
        gesture.minimumPressDuration = 0
        handle.addGestureRecognizer(gesture)
        return handle
    }

    @objc
    private func handleReorderGesture(gesture: UIGestureRecognizer) {
        let collectionView = customView.collectionView
        let location = gesture.location(in: collectionView)

        switch gesture.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location) else { break }
            collectionView.beginInteractiveMovementForItem(at: indexPath)
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(
                CGPoint(x: collectionView.bounds.width / 2, y: location.y)
            )
        case .ended:
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }

    private func didReorder(transaction: NSDiffableDataSourceTransaction<WalletsListSection, WalletsListItem>) {
        guard let walletsSectionTransaction = transaction.sectionTransactions.first(where: {
            if case .wallets = $0.sectionIdentifier {
                return true
            }
            return false
        }) else {
            return
        }

        var moves = [(from: Int, to: Int)]()
        for update in walletsSectionTransaction.difference.inferringMoves() {
            if case let .remove(offset, _, .some(move)) = update {
                moves.append((offset, move))
            }
        }
        for move in moves {
            viewModel.moveWallet(fromIndex: move.from, toIndex: move.to)
        }
    }

    /// Resolved by wallet identity rather than by position: the selection is also applied outside the
    /// `dataSource.apply` completion, where the store can already be ahead of what the collection view holds.
    static func walletIndexPath(for walletIdentifier: String, in snapshot: Snapshot) -> IndexPath? {
        guard let sectionIndex = snapshot.sectionIdentifiers.firstIndex(where: {
            if case .wallets = $0 {
                return true
            }
            return false
        }) else {
            return nil
        }
        guard let itemIndex = snapshot
            .itemIdentifiers(inSection: snapshot.sectionIdentifiers[sectionIndex])
            .firstIndex(where: { $0.identifier == walletIdentifier })
        else {
            return nil
        }
        return IndexPath(item: itemIndex, section: sectionIndex)
    }

    private func selectWallet() {
        let collectionView = customView.collectionView
        guard let walletIdentifier = viewModel.selectedWalletIdentifier,
              let indexPath = Self.walletIndexPath(for: walletIdentifier, in: dataSource.snapshot()),
              indexPath.section < collectionView.numberOfSections,
              indexPath.item < collectionView.numberOfItems(inSection: indexPath.section)
        else {
            return
        }
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }

    private func restoreContentOffset(_ contentOffset: CGPoint) {
        let collectionView = customView.collectionView
        let maxY = max(collectionView.contentSize.height - collectionView.bounds.height, 0)
        collectionView.contentOffset = CGPoint(x: contentOffset.x, y: min(contentOffset.y, maxY))
    }

    private func showAddMultichainWalletTooltipIfNeeded() {
        guard shouldShowAddMultichainWalletTooltip,
              !didAttemptAddMultichainWalletTooltip,
              let tooltipsService,
              !customView.collectionView.isEditing,
              let footer = addWalletFooterView()
        else {
            return
        }
        didAttemptAddMultichainWalletTooltip = true

        customView.collectionView.layoutIfNeeded()
        tooltipsService.showTooltipIfNeeded(
            id: .addMultichainWalletWalletsList,
            sourceView: footer.button,
            targetActionViews: [footer.button],
            configuration: HintConfiguration(
                position: HintPosition(
                    tailParameters: TKTooltipView.tailParameters,
                    horizontal: .default,
                    vertical: .init(absolute: 0),
                    direction: .topCenter
                ),
                maximumWidth: AddMultichainWalletTooltipLayout.maximumWidth,
                animationStyle: .bouncing
            ),
            onTargetAction: { [weak self] in
                self?.viewModel.didTapAddWallet()
            }
        )
    }

    private func addWalletFooterView() -> TKListCollectionViewButtonFooterView? {
        guard let walletsSectionIndex = dataSource.snapshot().sectionIdentifiers.firstIndex(where: {
            if case .wallets = $0 {
                return true
            }
            return false
        }) else {
            return nil
        }
        return customView.collectionView.supplementaryView(
            forElementKind: TKListCollectionViewButtonFooterView.elementKind,
            at: IndexPath(item: 0, section: walletsSectionIndex)
        ) as? TKListCollectionViewButtonFooterView
    }
}

extension WalletsListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard case .raffleBanner = dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
        viewModel.raffleBannerDidAppear()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
        item.onSelection?()
    }
}

private extension WalletsListViewController {
    enum Layout {
        static let raffleBannerHeight: CGFloat = 90
    }
}
