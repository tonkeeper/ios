import UIKit
import TKUIKit
import KeeperCore

public final class CurrencyPickerViewController: GenericViewViewController<CurrencyPickerView>, UICollectionViewDelegate {
    private let viewModel: CurrencyPickerViewModel
    private lazy var dataSource = createDataSource()
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in .defaultSection },
            configuration: configuration
        )
        return layout
    }()
    
    init(viewModel: CurrencyPickerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(false, animated: false)
        title = "Currency"
        
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case let model as CurrencyPickerSection.Item:
            model.model.selectionHandler?()
        default: 
            break
        }
    }
}

private extension CurrencyPickerViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.register(
            SettingsCell.self,
            forCellWithReuseIdentifier: SettingsCell.reuseIdentifier
        )
    }
    
    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] section in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections([section])
            snapshot.appendItems(section.items, toSection: section)
            self.dataSource.apply(snapshot, animatingDifferences: false) {
                if let initialSelectedCurrency = self.viewModel.initialSelectedCurrency {
                    self.initialSelect(currency: initialSelectedCurrency)
                }
            }
        }
    }
    
    func initialSelect(currency: Currency) {
        let snapshot = self.dataSource.snapshot()
        for section in snapshot.sectionIdentifiers {
            for item in snapshot.itemIdentifiers(inSection: section) {
                if let itemIdentifier = item as? CurrencyPickerSection.Item,
                   itemIdentifier.currency == currency {
                    if let sectionIndex = snapshot.indexOfSection(section),
                       let itemIndex = snapshot.indexOfItem(itemIdentifier) {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        self.customView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
                    }
                    return
                }
            }
        }
    }
}

private extension CurrencyPickerViewController {
    func createDataSource() -> UICollectionViewDiffableDataSource<CurrencyPickerSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<CurrencyPickerSection, AnyHashable>(
            collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let model as CurrencyPickerSection.Item:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SettingsCell.reuseIdentifier, for: indexPath) as? SettingsCell {
                        cell.configure(model: model.model)
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
    static let defaultSection: NSCollectionLayoutSection = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(56.0)
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
