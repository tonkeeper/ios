import TKUIKit
import UIKit

final class BuySellListViewController: GenericViewViewController<BuySellListView>, TKBottomSheetScrollContentViewController {
    private let viewModel: BuySellListViewModel

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        customView.collectionView
    }

    var emptyView = UIView()

    var didUpdateHeight: (() -> Void)?

    var headerItem: TKUIKit.TKPullCardHeaderItem? {
        TKUIKit.TKPullCardHeaderItem(title: .customView(segmentedControl), isTitleCentered: true)
    }

    var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        switch state {
        case .list:
            return scrollView.contentSize.height
        case .loading:
            return customView.loadingView
                .systemLayoutSizeFitting(CGSize(width: width, height: 0)).height
        }
    }

    private let segmentedControl = BuySellListSegmentedControl()

    // MARK: - State

    enum State {
        case loading
        case list
    }

    private var state: State = .loading {
        didSet {
            switch state {
            case .loading:
                customView.loadingView.loaderView.startAnimation()
                customView.collectionView.isHidden = true
                customView.loadingView.isHidden = false
            case .list:
                customView.loadingView.loaderView.stopAnimation()
                customView.loadingView.isHidden = true
                customView.collectionView.isHidden = false
            }
            didUpdateHeight?()
        }
    }

    // MARK: - List

    private lazy var layout = createLayout()
    private lazy var dataSource = createDataSource()

    // MARK: - Init

    init(viewModel: BuySellListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBindings()
        setupViewEvents()
        viewModel.viewDidLoad()
    }
}

private extension BuySellListViewController {
    func setup() {
        state = .loading

        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.register(
            BuyListSectionHeaderView.self,
            forSupplementaryViewOfKind: .sectionHeaderIdentifier,
            withReuseIdentifier: BuyListSectionHeaderView.reuseIdentifier
        )
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.dataSource.apply(snapshot, animatingDifferences: false, completion: {
                self.didUpdateHeight?()
            })
            self.didUpdateHeight?()
        }

        viewModel.didUpdateState = { [weak self] state in
            self?.state = state
        }

        viewModel.didUpdateSegmentedControl = { [weak self] model in
            if let model {
                self?.segmentedControl.isHidden = false
                self?.segmentedControl.configure(model: model)
            } else {
                self?.segmentedControl.isHidden = true
            }
        }
    }

    func setupViewEvents() {
        segmentedControl.didSelectTab = { [weak self] index in
            self?.viewModel.selectTab(index: index)
        }
    }

    func createDataSource() -> BuySellList.DataSource {
        let itemCellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        let buttonCellConfiguration = UICollectionView.CellRegistration<TKButtonCell, TKButtonCell.Model> {
            cell, _, identifier in
            cell.configure(model: identifier)
        }
        let dataSource = BuySellList.DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let .item(item):
                let cell = collectionView.dequeueConfiguredReusableCell(
                    using: itemCellConfiguration,
                    for: indexPath,
                    item: item.configuration
                )
                cell.defaultAccessoryViews = [TKListItemAccessory.chevron.view]
                return cell
            case let .button(buttonModel):
                return collectionView.dequeueConfiguredReusableCell(
                    using: buttonCellConfiguration,
                    for: indexPath,
                    item: buttonModel
                )
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case let .items(_, title, assets):
                let model = BuyListSectionHeaderView.Model(
                    titleViewModel: TKListTitleView.Model(title: title, textStyle: .h3),
                    assetsViewModel: BuyListSectionHeaderAssetsView.Model(
                        assets: assets.map { BuyListSectionHeaderAssetsView.Model.Asset(image: $0) }
                    )
                )
                let view = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: BuyListSectionHeaderView.reuseIdentifier,
                    for: indexPath
                )
                (view as? BuyListSectionHeaderView)?.configure(model: model)
                return view
            default:
                return nil
            }
        }

        return dataSource
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: { [dataSource] sectionIndex, _ in
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]

            let itemLayoutSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(96)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

            let groupLayoutSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(96)
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

            switch section {
            case .items:
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(56)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: .sectionHeaderIdentifier,
                    alignment: .top
                )
                layoutSection.boundarySupplementaryItems = [header]
            default:
                break
            }

            return layoutSection
        }, configuration: configuration)
    }
}

extension BuySellListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
        switch item {
        case let .item(item):
            item.selectionHandler?()
        default:
            break
        }
    }
}

private extension String {
    static let sectionHeaderIdentifier = "SectionHeaderIdentifier"
}
