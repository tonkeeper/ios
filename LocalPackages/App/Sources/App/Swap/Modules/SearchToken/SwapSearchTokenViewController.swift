import TKUIKit
import UIKit
import TKCoordinator

final class SwapSearchTokenViewController: GenericViewViewController<SwapSearchTokenView>, ScrollViewController, UICollectionViewDelegate {
    typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
    
    private let viewModel: SwapSearchTokenViewModel
        
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [dataSource] sectionIndex, _ in
                let snapshot = dataSource.snapshot()
                switch snapshot.sectionIdentifiers[sectionIndex] {
                case .other:
                    return .otherSection
                case .suggested:
                    return .suggestedSection
                }
            },
            configuration: configuration
        )
        return layout
    }()
    
    private lazy var dataSource = createDataSource()
    private lazy var otherCellConfiguration = UICollectionView.CellRegistration<SwapSearchTokenOtherCell, SwapSearchTokenOtherCell.Model> { [weak self]
        cell, indexPath, itemIdentifier in
        cell.configure(model: itemIdentifier)
    }
    private lazy var suggestedCellConfiguration = UICollectionView.CellRegistration<SwapSearchTokenSuggestedCell, SwapSearchTokenSuggestedCell.Model> { [weak self]
        cell, indexPath, itemIdentifier in
        cell.configure(model: itemIdentifier)
    }
    
    init(viewModel: SwapSearchTokenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
    
    func scrollToTop() {}
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        let item = dataSource.snapshot().itemIdentifiers(inSection: section)[indexPath.item]
        
        switch item {
        case let model as SwapSearchTokenOtherCell.Model:
            model.selectionHandler?()
        case let model as SwapSearchTokenSuggestedCell.Model:
            model.selectionHandler?()
        default:
            break
        }
    }
}

private extension SwapSearchTokenViewController {
    func setup() {
        
        customView.closeButton.addTapAction { [weak self] in
            self?.viewModel.didTapCloseButton()
        }
        
        customView.textField.didUpdateText = { [weak self] searchText in
            self?.viewModel.didUpdateText(text: searchText)
        }
        
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.register(
            SwapSearchTokenOtherCell.self,
            forCellWithReuseIdentifier: SwapSearchTokenOtherCell.reuseIdentifier
        )
        customView.collectionView.register(
            SwapSearchTokenSuggestedCell.self,
            forCellWithReuseIdentifier: SwapSearchTokenSuggestedCell.reuseIdentifier
        )
        customView.collectionView.register(
          SectionHeaderView.self,
          forSupplementaryViewOfKind: .sectionHeaderElementKind,
          withReuseIdentifier: SectionHeaderView.reuseIdentifier
        )
    }
    
    func setupBindings() {
        viewModel.didUpdateModel = { [weak dataSource] model in
            guard let dataSource else { return }
            var snapshot = dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections(model.sections)
            for section in model.sections {
                switch section {
                case .other(items: let items):
                    snapshot.appendItems(items, toSection: section)
                case .suggested(items: let items):
                    snapshot.appendItems(items, toSection: section)
                }
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    func createDataSource() -> UICollectionViewDiffableDataSource<SwapSearchTokenSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<SwapSearchTokenSection, AnyHashable>(
            collectionView: customView.collectionView) { [otherCellConfiguration, suggestedCellConfiguration] collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let configuration as SwapSearchTokenOtherCell.Model:
                    let cell = collectionView.dequeueConfiguredReusableCell(using: otherCellConfiguration, for: indexPath, item: configuration)
                    cell.isFirstInSection = { return $0.item == 0 }
                    cell.isLastInSection = { [unowned collectionView] in
                      let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                      return $0.item == numberOfItems - 1
                    }
                    return cell
                case let configuration as SwapSearchTokenSuggestedCell.Model:
                    let cell = collectionView.dequeueConfiguredReusableCell(using: suggestedCellConfiguration, for: indexPath, item: configuration)
                    cell.isFirstInSection = { return $0.item == 0 }
                    cell.isLastInSection = { [unowned collectionView] in
                      let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                      return $0.item == numberOfItems - 1
                    }
                    return cell
                default: return nil
                }
            }
        
        dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
            guard let dataSource else { return nil }
            let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.reuseIdentifier,
                for: indexPath
            )
            let snapshot = dataSource.snapshot()
            let headerTitle = snapshot.sectionIdentifiers[indexPath.section].headerTitle
            (sectionHeaderView as? SectionHeaderView)?.configure(model: TKListTitleView.Model(title: headerTitle, textStyle: .h3))
            return sectionHeaderView
        }
        
        return dataSource
    }
}


private extension String {
    static let sectionHeaderElementKind = "SectionHeaderElementKind"
}

private extension NSCollectionLayoutSection {
    static var suggestedSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .estimated(106),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(106),
            heightDimension: .estimated(40)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        section.interGroupSpacing = 8
        
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
        section.orthogonalScrollingBehavior = .continuous
        
        return section
    }
    
    static var otherSection: NSCollectionLayoutSection {
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
    }
}
