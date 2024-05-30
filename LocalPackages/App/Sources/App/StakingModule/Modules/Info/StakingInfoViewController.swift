import UIKit
import TKUIKit
import TKCoordinator

final class StakingInfoViewController: GenericViewViewController<StakingInfoView> {
    typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
    typealias SectionFooterView = TKCollectionViewSupplementaryContainerView<StakingInfoFooterView>
    
    private let viewModel: StakingInfoViewModel
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(0)
        )
        
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, _ in
                guard let self else { return nil }
                let snapshot = self.dataSource.snapshot()
                let section = snapshot.sectionIdentifiers[sectionIndex]
                switch section {
                case .info:
                    return .infoSection
                case .social:
                    return .socialSection
                }
            },
            configuration: configuration
        )
        return layout
    }()
    
    private lazy var dataSource = createDataSource()
    
    init(viewModel: StakingInfoViewModel) {
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
}

private extension StakingInfoViewController {
    func setup() {
        customView.continueButton.configuration = .actionButtonConfiguration(category: .primary, size: .large)
        customView.continueButton.configuration.content.title = .plainString("Choose")
        customView.continueButton.configuration.action = { [weak self] in
            self?.viewModel.didTapContinueButton()
        }
        
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.register(
            StakingInfoCell.self,
            forCellWithReuseIdentifier: StakingInfoCell.reuseIdentifier
        )
        customView.collectionView.register(
            StakingInfoSocialCell.self,
            forCellWithReuseIdentifier: StakingInfoSocialCell.reuseIdentifier
        )
        customView.collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: .sectionHeaderElementKind,
            withReuseIdentifier: SectionHeaderView.reuseIdentifier
        )
        customView.collectionView.register(
            SectionFooterView.self,
            forSupplementaryViewOfKind: .sectionFooterElementKind,
            withReuseIdentifier: SectionFooterView.reuseIdentifier
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
                case .info(let items):
                    snapshot.appendItems(items, toSection: section)
                case .social(let items):
                    snapshot.appendItems(items, toSection: section)
                }
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    func createDataSource() -> UICollectionViewDiffableDataSource<StakingInfoSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<StakingInfoSection, AnyHashable>(
            collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let model as StakingInfoCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StakingInfoCell.reuseIdentifier, for: indexPath) as? StakingInfoCell {
                        cell.configure(model: model)
                        cell.isFirstInSection = { return $0.item == 0 }
                        cell.isLastInSection = { [unowned collectionView] in
                            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                            return $0.item == numberOfItems - 1
                        }
                        return cell
                    }
                    return nil
                case let model as StakingInfoSocialCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StakingInfoSocialCell.reuseIdentifier, for: indexPath) as? StakingInfoSocialCell {
                        cell.configure(model: model)
                        return cell
                    }
                    return nil
                default: return nil
                }
            }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
            guard let self else { return nil}
            
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            
            switch section {
            case .info:
                let sectionFooterView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: SectionFooterView.reuseIdentifier,
                    for: indexPath
                )
                (sectionFooterView as? SectionFooterView)?.configure(
                    model: .init(title: "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.")
                )
                return sectionFooterView
            case .social:
                let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: SectionHeaderView.reuseIdentifier,
                    for: indexPath
                )
                (sectionHeaderView as? SectionHeaderView)?.configure(
                    model: TKListTitleView.Model(title: section.description, textStyle: .h3)
                )
                return sectionHeaderView
            }
        }
        
        return dataSource
    }
}


private extension String {
    static let sectionHeaderElementKind = "SectionHeaderElementKind"
    static let sectionFooterElementKind = "SectionHeaderElementKind"
}

private extension NSCollectionLayoutSection {
    static let infoSection: NSCollectionLayoutSection = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(36)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(36)
        )
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        
        let fooerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(60)
        )
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: fooerSize,
            elementKind: .sectionFooterElementKind,
            alignment: .bottom
        )
        section.boundarySupplementaryItems = [footer]
        
        return section
    }()
    
    static let socialSection: NSCollectionLayoutSection = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .estimated(108),
            heightDimension: .estimated(36)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(36)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        group.interItemSpacing = .fixed(8)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        section.interGroupSpacing = 8
        
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(56)
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
