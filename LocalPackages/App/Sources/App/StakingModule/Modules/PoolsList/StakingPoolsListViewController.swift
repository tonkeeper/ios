import UIKit
import TKUIKit
import TKCoordinator

final class StakingPoolsListViewController: GenericViewViewController<StakingPoolsListView>, UICollectionViewDelegate {
    private let viewModel: StakingPoolsListViewModel
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(0)
        )
        
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in .defaultSection },
            configuration: configuration
        )
        return layout
    }()
    
    private lazy var dataSource = createDataSource()
    
    init(viewModel: StakingPoolsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case let model as StakingPoolsCell.Model:
            model.selectionHandler?()
        default:
            break
        }
    }
}

private extension StakingPoolsListViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.register(
            StakingPoolsCell.self,
            forCellWithReuseIdentifier: StakingPoolsCell.reuseIdentifier
        )
    }
    
    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] section in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections([section])
            snapshot.appendItems(section.items, toSection: section)
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    func createDataSource() -> UICollectionViewDiffableDataSource<StakingPoolsListSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<StakingPoolsListSection, AnyHashable>(
            collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let model as StakingPoolsCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StakingPoolsCell.reuseIdentifier, for: indexPath) as? StakingPoolsCell {
                        cell.configure(model: model)
                        cell.isFirstInSection = { return $0.item == 0 }
                        cell.isLastInSection = { [unowned collectionView] in
                            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                            return $0.item == numberOfItems - 1
                        }
                        return cell
                    }
                    return nil
                default: return nil
                }
            }
        return dataSource
    }
}

private extension NSCollectionLayoutSection {
    static let defaultSection: NSCollectionLayoutSection = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
        )
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        
        return section
    }()
}
