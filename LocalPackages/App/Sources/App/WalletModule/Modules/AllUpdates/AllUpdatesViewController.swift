import KeeperCore
import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

typealias AllUpdates = AllUpdatesViewController

final class AllUpdatesViewController: GenericViewViewController<AllUpdatesView> {
    private let viewModel: AllUpdatesViewModel

    private lazy var layout = createLayout()
    private lazy var dataSource = createDataSource()

    // MARK: - Init

    init(viewModel: AllUpdatesViewModel) {
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
        viewModel.viewDidLoad()
    }

    // MARK: - Setup

    private func setup() {
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.contentInsetAdjustmentBehavior = .never
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        customView.titleView.configure(
            model: TKUINavigationBarTitleView.Model(
                title: TKLocales.StoriesUpdates.allUpdates.withTextStyle(
                    .h3,
                    color: .Text.primary,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                )
            )
        )

        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.dismiss(animated: true)
            },
        ]
    }

    private func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            self?.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
}

extension AllUpdatesViewController {
    enum Section: Hashable {
        case main
    }

    struct Item: Hashable {
        let id: String
        let story: KeeperCore.Story
        let selectionHandler: () -> Void

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.id == rhs.id
        }
    }

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
}

private extension AllUpdatesViewController {
    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] _, _ in
                return self?.createListSection()
            },
            configuration: configuration
        )
    }

    func createListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(300)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(300)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
        section.interGroupSpacing = 0

        return section
    }

    func createDataSource() -> DataSource {
        let cellRegistration = UICollectionView.CellRegistration<AllUpdatesStoryCell, Item> { cell, _, item in
            let configuration = AllUpdatesStoryCell.Configuration(
                id: item.id,
                previewURL: item.story.preview,
                title: item.story.main_screen.title,
                description: item.story.main_screen.description
            )
            cell.configure(model: configuration)
        }

        return DataSource(collectionView: customView.collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }
    }
}

extension AllUpdatesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        item.selectionHandler()
    }
}
