import TKUIKit
import UIKit

final class AddWalletOptionPickerViewController: GenericViewViewController<AddWalletOptionPickerView>, TKBottomSheetScrollContentViewController {
    private let viewModel: AddWalletOptionPickerViewModel

    init(viewModel: AddWalletOptionPickerViewModel) {
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

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        customView.collectionView
    }

    var didUpdateHeight: (() -> Void)?
    var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
    var headerItem: TKUIKit.TKPullCardHeaderItem?
    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        scrollView.contentSize.height + view.safeAreaInsets.bottom
    }

    private func setup() {
        customView.collectionView.collectionViewLayout = layout
        customView.collectionView.delegate = self
    }

    private func setupBindings() {
        viewModel.didUpdateHeaderViewModel = { [weak self] model in
            self?.customView.titleDescriptionView.configure(model: model)
        }
        viewModel.didUpdateOptionsSections = { [weak self] sections in
            guard let self else { return }
            var snapshot = NSDiffableDataSourceSnapshot<AddWalletOptionPickerSection, AddWalletOptionPickerItem>()
            snapshot.appendSections(sections)
            for section in sections {
                snapshot.appendItems(section.items, toSection: section)
            }
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private lazy var dataSource: UICollectionViewDiffableDataSource<AddWalletOptionPickerSection, AddWalletOptionPickerItem> = {
        let headerRegistration = UICollectionView.SupplementaryRegistration<TKReusableContainerView>(
            elementKind: .headerIdentifier
        ) { [weak self] supplementaryView, _, _ in
            supplementaryView.setContentView(self?.customView.titleDescriptionView)
        }
        let sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<AddWalletOptionPickerSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] supplementaryView, _, indexPath in
            guard let self else { return }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            if let header = section.header, !header.isEmpty {
                supplementaryView.titleLabel.attributedText = header.withTextStyle(
                    .body1,
                    color: .Text.secondary,
                    alignment: .center,
                    lineBreakMode: .byWordWrapping
                )
                supplementaryView.isHidden = false
            } else {
                supplementaryView.titleLabel.attributedText = nil
                supplementaryView.isHidden = true
            }
        }
        let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        let dataSource = UICollectionViewDiffableDataSource<AddWalletOptionPickerSection, AddWalletOptionPickerItem>(
            collectionView: customView.collectionView
        ) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: itemIdentifier.cellConfiguration)
            let accessoryView = TKListItemIconAccessoryView()
            accessoryView.configuration = .chevron
            cell.defaultAccessoryViews = [accessoryView]
            return cell
        }
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            switch elementKind {
            case .headerIdentifier:
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderRegistration, for: indexPath)
            default:
                return nil
            }
        }
        return dataSource
    }()

    private var layout: UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        configuration.boundarySupplementaryItems = [makeGlobalHeader()]

        return UICollectionViewCompositionalLayout(sectionProvider: sectionLayoutProvider, configuration: configuration)
    }
}

// MARK: - Layout

private extension AddWalletOptionPickerViewController {
    func sectionLayoutProvider(sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        guard let section = self.dataSource.snapshot().sectionIdentifiers[safe: sectionIndex] else { return nil }
        return makeSectionLayout(for: section)
    }

    func makeSectionLayout(for section: AddWalletOptionPickerSection) -> NSCollectionLayoutSection {
        let widthDimension: NSCollectionLayoutDimension = .fractionalWidth(1.0)
        let heightDimension: NSCollectionLayoutDimension = .estimated(76)

        let itemSize = NSCollectionLayoutSize(widthDimension: widthDimension, heightDimension: heightDimension)
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 32)

        if let header = section.header, !header.isEmpty {
            sectionLayout.boundarySupplementaryItems = [makeSectionHeader()]
        }
        return sectionLayout
    }

    func makeGlobalHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(0)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: .headerIdentifier,
            alignment: .top
        )
    }

    func makeSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let sectionHeaderSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(50)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: sectionHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        sectionHeader.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        return sectionHeader
    }
}

extension AddWalletOptionPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
        viewModel.didSelectItem(item)
    }
}

private extension String {
    static let headerIdentifier = "HeaderIdentifier"
}
