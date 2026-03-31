import TKCoordinator
import TKUIKit
import UIKit

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView>, ScrollViewController, WalletContainerBalanceViewController {
    var didScroll: ((CGFloat) -> Void)?

    private var balanceItemsConfigurations = [String: WalletBalanceListCell.Configuration]()

    private let viewModel: WalletBalanceViewModel
    private lazy var tooltipDismissGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTapWhileTooltipVisible))
        recognizer.cancelsTouchesInView = false
        recognizer.isEnabled = false
        return recognizer
    }()

    init(viewModel: WalletBalanceViewModel) {
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
        scrollToTop(animated: true)
    }

    func setup() {
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.showsVerticalScrollIndicator = false
        customView.addGestureRecognizer(tooltipDismissGestureRecognizer)
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
            if isAnimated {
                dataSource.apply(snapshot, animatingDifferences: true)
            } else {
                if #available(iOS 15.0, *) {
                    dataSource.applySnapshotUsingReloadData(snapshot, completion: nil)
                } else {
                    dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }

        viewModel.didUpdateHeader = { [weak self] model in
            guard let self else { return }
            customView.headerView.configure(model: model)
            tooltipDismissGestureRecognizer.isEnabled = model.hasWithdrawTooltip
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
                    return
                }
                cell.configuration = item.value
            }
        }
        viewModel.didCopy = { configuration in
            ToastPresenter.showToast(configuration: configuration)
        }
    }

    private lazy var dataSource: WalletBalance.DataSource = {
        let balanceListCellRegistration = WalletBalanceListCellRegistration.registration(collectionView: customView.collectionView)
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
            }
        }

        let listButtonFooterRegistration = TKListCollectionViewButtonFooterViewRegistration.registration()
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
            case TKListCollectionViewButtonFooterView.elementKind:
                guard let snapshot = self?.dataSource.snapshot() else { return nil }
                let snapshotSection = snapshot.sectionIdentifiers[indexPath.section]
                switch snapshotSection {
                case let .balance(balanceSection):
                    guard let configuration = balanceSection.footerConfiguration else { return nil }
                    let view = collectionView.dequeueConfiguredReusableSupplementary(
                        using: listButtonFooterRegistration,
                        for: indexPath
                    )
                    view.configuration = configuration
                    return view
                default: return nil
                }
            case TKListCollectionViewButtonHeaderView.elementKind:
                guard let snapshot = self?.dataSource.snapshot() else { return nil }
                let snapshotSection = snapshot.sectionIdentifiers[indexPath.section]
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
    @objc
    func didTapWhileTooltipVisible(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: customView.headerView)
        if customView.headerView.isWithdrawTooltipContains(point: location) {
            viewModel.markWithdrawTooltipInstructionUnderstood()
        } else {
            viewModel.dismissWithdrawTooltip()
        }
    }

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

    private var layout: UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(
            sectionProvider: { [weak dataSource] sectionIndex, _ in
                guard let dataSource else { return nil }
                let snapshotSection = dataSource.snapshot().sectionIdentifiers[sectionIndex]

                switch snapshotSection {
                case .balanceHeader:
                    let itemLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(249)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

                    let groupLayoutSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(249)
                    )
                    let group = NSCollectionLayoutGroup.horizontal(
                        layoutSize: groupLayoutSize,
                        subitems: [item]
                    )

                    let layoutSection = NSCollectionLayoutSection(group: group)
                    layoutSection.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 16,
                        bottom: 16,
                        trailing: 16
                    )
                    return layoutSection
                case let .balance(section):
                    let sectionLayout: NSCollectionLayoutSection = .listItemsSection
                    sectionLayout.contentInsets.bottom = 16
                    if section.footerConfiguration != nil {
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
                    }

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
                }
            },
            configuration: configuration
        )
    }
}

extension WalletBalanceViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
        switch item {
        case let .listItem(listItem):
            listItem.onSelection?()
        default:
            return
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
    }
}

private extension String {
    static let balanceHeaderElementKind = "BalanceHeaderElementKind"
    static let setupSectionHeaderElementKind = "SetupSectionHeaderElementKind"
}
