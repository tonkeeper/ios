import TKCoordinator
import TKUIKit
import UIKit

final class CollectiblesListViewController: GenericViewViewController<CollectiblesListView>, ScrollViewController {
    typealias CollectibleCellConfiguration = UICollectionView.CellRegistration<CollectibleCollectionViewCell, String>

    var didScroll: ((_ scrollView: UIScrollView) -> Void)?

    private lazy var dataSource = createDataSource()

    var topInset: CGFloat = 0 {
        didSet {
            customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
        }
    }

    private var emptyViewController = TKEmptyViewController()
    private let viewModel: CollectiblesListViewModel

    init(viewModel: CollectiblesListViewModel) {
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
}

private extension CollectiblesListViewController {
    func setup() {
        customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
        customView.collectionView.delegate = self
        customView.collectionView.register(
            TKContainerCollectionViewCell.self,
            forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
        )
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            self?.customView.refreshControl.endRefreshing()
            if #available(iOS 15.0, *) {
                self?.dataSource.applySnapshotUsingReloadData(snapshot)
            } else {
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
        viewModel.didUpdateEmptyViewModel = { [weak self] model in
            self?.emptyViewController.configure(model: model)
        }
        viewModel.didStopLoading = { [weak self] in
            self?.customView.refreshControl.endRefreshing()
        }
    }

    func createDataSource() -> CollectiblesList.DataSource {
        let nftCellConfiguration = CollectibleCellConfiguration {
            [weak viewModel] cell, _, itemIdentifier in
            guard let model = viewModel?.getNFTCellModel(identifier: itemIdentifier) else { return }
            cell.configure(model: model)
        }

        return CollectiblesList.DataSource(collectionView: customView.collectionView) {
            [weak self] collectionView, indexPath, itemIdentifier in
            guard let self else { return nil }
            switch itemIdentifier {
            case let .nft(identifier):
                return collectionView.dequeueConfiguredReusableCell(
                    using: nftCellConfiguration,
                    for: indexPath,
                    item: identifier
                )
            case .empty:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
                    for: indexPath
                )
                emptyViewController.willMove(toParent: nil)
                emptyViewController.view.removeFromSuperview()
                emptyViewController.removeFromParent()

                addChild(emptyViewController)
                (cell as? TKContainerCollectionViewCell)?.setContentView(emptyViewController.view)
                emptyViewController.didMove(toParent: self)

                let height = collectionView.bounds.height
                    - collectionView.adjustedContentInset.top
                    - collectionView.adjustedContentInset.bottom
                    - topInset

                emptyViewController.view.snp.makeConstraints { make in
                    make.height.equalTo(height).priority(.high)
                }

                return cell
            }
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, _ in
                guard let self else { return nil }
                let snapshot = dataSource.snapshot()
                switch snapshot.sectionIdentifiers[sectionIndex] {
                case .all:
                    return allSectionLayout()
                case .empty:
                    return emptySectionLayout()
                }
            },
            configuration: configuration
        )
    }

    private func allSectionLayout() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / 3),
                heightDimension: .estimated(166)
            )
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(166)
            ),
            subitem: item,
            count: 3
        )
        group.interItemSpacing = .fixed(8)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
        )
        section.contentInsets.bottom = 16
        section.contentInsets.top = topInset
        section.interGroupSpacing = 8
        return section
    }

    private func emptySectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets.top = topInset
        return section
    }
}

extension CollectiblesListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.didSelectNftAt(index: indexPath.item)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll?(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if customView.refreshControl.isRefreshing {
            viewModel.reload()
        }
    }
}

extension CGFloat {
    static let itemAspectRatio: CGFloat = 144 / 166
}
