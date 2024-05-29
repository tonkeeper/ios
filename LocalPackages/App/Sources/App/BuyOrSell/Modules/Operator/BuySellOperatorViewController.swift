import UIKit
import TKUIKit

final class BuySellOperatorViewController: GenericViewViewController<BuySellOperatorView>, UICollectionViewDelegate {
    private let viewModel: BuySellOperatorViewModel
    private lazy var dataSource = createDataSource()
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, _ in
                guard let self else { return nil }
                let snapshot = self.dataSource.snapshot()
                let section = snapshot.sectionIdentifiers[sectionIndex]
                switch section {
                case .currency:
                    return .defaultSection(with: 56)
                case .operators:
                    return .defaultSection(with: 76)
                }
            },
            configuration: configuration
        )
        return layout
    }()
    
    init(viewModel: BuySellOperatorViewModel) {
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        
        switch section {
        case .currency:
            return true
        case .operators:
            let selectedIndices = collectionView.indexPathsForSelectedItems ?? []
            for selectedIndex in selectedIndices {
                if selectedIndex.section == indexPath.section {
                    collectionView.deselectItem(at: selectedIndex, animated: false)
                }
            }
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        
        switch section {
        case .currency:
            return true
        case .operators:
            let selectedIndices = collectionView.indexPathsForSelectedItems ?? []
            for selectedIndex in selectedIndices {
                if selectedIndex == indexPath {
                    return false
                }
            }
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case let model as BuySellCurrencyCell.Model:
            model.selectionHandler?()
            collectionView.deselectItem(at: indexPath, animated: false)
        case let model as BuySellOperatorCell.Model:
            model.selectionHandler?()
        default:
            break
        }
    }
}

private extension BuySellOperatorViewController {
    func setup() {
        customView.collectionView.allowsMultipleSelection = true
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.register(
            BuySellOperatorCell.self,
            forCellWithReuseIdentifier: BuySellOperatorCell.reuseIdentifier
        )
        customView.collectionView.register(
            BuySellCurrencyCell.self,
            forCellWithReuseIdentifier: BuySellCurrencyCell.reuseIdentifier
        )
        
        customView.backButton.addTapAction { [weak self] in
            self?.viewModel.didTapBackButton()
        }
        
        customView.closeButton.addTapAction { [weak self] in
            self?.viewModel.didTapCloseButton()
        }
    }
    
    func setupBindings() {
        viewModel.didUpdateCurrency = { [weak self] sectionForInsert in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()
            
            let sectionsForDelete = snapshot.sectionIdentifiers.filter {
                if case .currency = $0 {
                    return true
                }
                return false
            }
            
            snapshot.deleteSections(sectionsForDelete)
            
            if let beforeSection = snapshot.sectionIdentifiers.first {
                snapshot.insertSections([sectionForInsert], beforeSection: beforeSection)
            } else {
                snapshot.appendSections([sectionForInsert])
            }
            switch sectionForInsert {
            case .currency(let item):
                snapshot.appendItems([item], toSection: sectionForInsert)
            default:
                break
            }
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
        
        viewModel.didUpdateOperators = { [weak self] sectionsForInsert in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()
            
            let sectionsForDelete = snapshot.sectionIdentifiers.filter {
                if case .operators = $0 {
                    return true
                }
                return false
            }
            
            snapshot.deleteSections(sectionsForDelete)
            
            snapshot.appendSections(sectionsForInsert)
            for section in sectionsForInsert {
                switch section {
                case .operators(let items):
                    snapshot.appendItems(items, toSection: section)
                default:
                    break
                }
            }
            self.dataSource.apply(snapshot, animatingDifferences: false) {
                let sectionIndex = snapshot.sectionIdentifiers.firstIndex(where: {
                    if case .operators = $0 {
                        return true
                    }
                    return false
                })
                if let sectionIndex, case .operators(let items) = snapshot.sectionIdentifiers[sectionIndex], !items.isEmpty {
                    let section = snapshot.sectionIdentifiers[sectionIndex]
                    let item = snapshot.itemIdentifiers(inSection: section).first
                    if let item {
                        switch item {
                        case let model as BuySellOperatorCell.Model:
                            model.selectionHandler?()
                        default:
                            break
                        }
                    }
                    self.customView.collectionView.selectItem(at: .init(item: 0, section: sectionIndex), animated: false, scrollPosition: .top)
                }
            }
        }
    }
}

private extension BuySellOperatorViewController {
    func createDataSource() -> UICollectionViewDiffableDataSource<BuySellOperatorSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<BuySellOperatorSection, AnyHashable>(
            collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let model as BuySellOperatorCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BuySellOperatorCell.reuseIdentifier, for: indexPath) as? BuySellOperatorCell {
                        cell.configure(model: model)
                        cell.isFirstInSection = { return $0.item == 0 }
                        cell.isLastInSection = { [unowned collectionView] in
                            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                            return $0.item == numberOfItems - 1
                        }
                        return cell
                    }
                case let model as BuySellCurrencyCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BuySellCurrencyCell.reuseIdentifier, for: indexPath) as? BuySellCurrencyCell {
                        cell.configure(model: model)
                        cell.isFirstInSection = { return $0.item == 0 }
                        cell.isLastInSection = { [unowned collectionView] in
                            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                            return $0.item == numberOfItems - 1
                        }
                        return cell
                    }
                default: return nil
                }
                return nil
            }
        return dataSource
    }
}

private extension NSCollectionLayoutSection {
    static func defaultSection(with itemHeight: CGFloat) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(itemHeight)
        )
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        
        return section
    }
}
