import UIKit
import TKUIKit
import TKCoordinator

final class StakingOptionsListViewController: GenericViewViewController<StakingOptionsListView>, UICollectionViewDelegate {
    typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
    
    private let viewModel: StakingOptionsListViewModel
    
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
    
    init(viewModel: StakingOptionsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Options"
        
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = self.dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case let model as StakingOptionsCell.Model:
            model.selectionHandler?()
        case let model as StakingOptionsOtherCell.Model:
            model.selectionHandler?()
        default:
            break
        }
    }
}

private extension StakingOptionsListViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.register(
            StakingOptionsCell.self,
            forCellWithReuseIdentifier: StakingOptionsCell.reuseIdentifier
        )
        customView.collectionView.register(
            StakingOptionsOtherCell.self,
            forCellWithReuseIdentifier: StakingOptionsOtherCell.reuseIdentifier
        )
        customView.collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: .sectionHeaderElementKind,
            withReuseIdentifier: SectionHeaderView.reuseIdentifier
        )
    }
    
    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] sections in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections(sections)
            for section in sections{
                switch section {
                case .staking(let items):
                    snapshot.appendItems(items, toSection: section)
                case .other(items: let items):
                    snapshot.appendItems(items, toSection: section)
                }
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    func createDataSource() -> UICollectionViewDiffableDataSource<StakingOptionsSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<StakingOptionsSection, AnyHashable>(
            collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let model as StakingOptionsCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StakingOptionsCell.reuseIdentifier, for: indexPath) as? StakingOptionsCell {
                        cell.configure(model: model)
                        cell.isFirstInSection = { return $0.item == 0 }
                        cell.isLastInSection = { [unowned collectionView] in
                            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                            return $0.item == numberOfItems - 1
                        }
                        return cell
                    }
                    return nil
                case let model as StakingOptionsOtherCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StakingOptionsOtherCell.reuseIdentifier, for: indexPath) as? StakingOptionsOtherCell {
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
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
            guard let self else { return nil}
            let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.reuseIdentifier,
                for: indexPath
            )
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            (sectionHeaderView as? SectionHeaderView)?.configure(
                model: TKListTitleView.Model(title: section.description, textStyle: .h3)
            )
            return sectionHeaderView
        }
        
        return dataSource
    }
}


private extension String {
    static let sectionHeaderElementKind = "SectionHeaderElementKind"
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
        
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(56)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: .sectionHeaderElementKind,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }()
}
