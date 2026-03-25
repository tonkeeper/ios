import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class BrowserCategoryViewController: GenericViewViewController<BrowserCategoryView> {
    private let viewModel: BrowserCategoryViewModel

    private lazy var dataSource = createDataSource()

    init(viewModel: BrowserCategoryViewModel) {
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

    private func setupNavigationBar() {
        guard let navigationController,
              !navigationController.viewControllers.isEmpty
        else {
            return
        }
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton {
                navigationController.popViewController(animated: true)
            },
        ]
    }
}

extension BrowserCategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = dataSource
            .snapshot()
            .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
        item.selectionHandler?()
    }
}

// MARK: - Private

private extension BrowserCategoryViewController {
    func setup() {
        setupNavigationBar()

        customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
        customView.collectionView.delegate = self

        customView.searchBar.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(
                    didTapSearchBar
                )
            )
        )
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            self?.dataSource.apply(snapshot, animatingDifferences: false)
        }

        viewModel.didUpdateTitle = { [weak self] title in
            self?.customView.titleView.configure(model: TKUINavigationBarTitleView.Model(title: title))
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(84)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(84)
            )

            let group: NSCollectionLayoutGroup

            if #available(iOS 16.0, *) {
                group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    repeatingSubitem: item,
                    count: 1
                )
            } else {
                group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitem: item,
                    count: 1
                )
            }

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 10, leading: 16, bottom: 16, trailing: 16)
            return section
        }
    }

    func createDataSource() -> BrowserCategory.DataSource {
        let itemCellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        return BrowserCategory.DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: itemCellConfiguration,
                for: indexPath,
                item: itemIdentifier.configuration
            )
            cell.defaultAccessoryViews = [TKListItemAccessory.chevron.view]
            return cell
        }
    }

    @objc
    func didTapSearchBar() {
        viewModel.didTapSearchBar()
    }
}
