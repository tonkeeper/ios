import UIKit
import TKUIKit

final class BuySellViewController: GenericViewViewController<BuySellView> {
    private let viewModel: BuySellViewModel
    private let amountInputViewController = AmountInputViewController()
    
    private lazy var dataSource = createDataSource()
    
    private lazy var methodCellConfiguration = UICollectionView.CellRegistration<BuySellMethodCell, BuySellMethodCell.Model> { [weak self]
        cell, indexPath, itemIdentifier in
        cell.configure(model: itemIdentifier)
    }
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in .methodsSection  },
            configuration: configuration
        )
        return layout
    }()
    
    init(viewModel: BuySellViewModel) {
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
        setupViewEventsBinding()
        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

private extension BuySellViewController {
    func setup() {
        addChild(amountInputViewController)
        customView.embedAmountInputView(amountInputViewController.view)
        amountInputViewController.didMove(toParent: self)
        
        customView.methodsCollectionView.setCollectionViewLayout(layout, animated: false)
        customView.methodsCollectionView.register(
            BuySellMethodCell.self,
            forCellWithReuseIdentifier: BuySellMethodCell.reuseIdentifier
        )
    }
    
    func setupBindings() {
        viewModel.didUpdateInputConvertedValue = { [weak self] text in
            self?.amountInputViewController.inputValue = text
        }
        
        viewModel.didUpdateInput = { [weak self] model in
            guard let self else { return }
            self.amountInputViewController.convertedValue = model.convertedValue
            self.amountInputViewController.inputSymbol = model.inputSymbol
            self.amountInputViewController.maximumFractionDigits = model.maximumFractionDigits
            self.amountInputViewController.isTokenPickerAvailable = false
            self.amountInputViewController.descriptionText = "Min. amount: 50 TON"
        }
        
        viewModel.didUpdateMethods = { [weak dataSource] section in
            guard let dataSource else { return }
            var snapshot = dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections([section])
            snapshot.appendItems(section.items, toSection: section)
            dataSource.apply(snapshot, animatingDifferences: false) {
                if !snapshot.sectionIdentifiers.isEmpty {
                    let sectionIndex = 0
                    let section = snapshot.sectionIdentifiers[sectionIndex]
                    if snapshot.itemIdentifiers(inSection: section).isEmpty { return }
                    let item = snapshot.itemIdentifiers(inSection: section).first
                    if let item {
                        switch item {
                        case let model as BuySellOperatorCell.Model:
                            model.selectionHandler?()
                        default:
                            break
                        }
                    }
                    self.customView.methodsCollectionView.selectItem(
                        at: .init(item: 0, section: sectionIndex),
                        animated: false,
                        scrollPosition: .top
                    )
                }
            }
        }
    }
    
    func setupViewEventsBinding() {
        amountInputViewController.didUpdateText = { [weak viewModel] text in
            viewModel?.didEditInput(text)
        }
        
        amountInputViewController.didToggle = { [weak viewModel] in
            viewModel?.toggleInputMode()
        }
    }
}

private extension BuySellViewController {
    func createDataSource() -> UICollectionViewDiffableDataSource<BuySellMethodSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<BuySellMethodSection, AnyHashable>(
            collectionView: customView.methodsCollectionView) { [methodCellConfiguration] collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let configuration as BuySellMethodCell.Model:
                    let cell = collectionView.dequeueConfiguredReusableCell(using: methodCellConfiguration, for: indexPath, item: configuration)
                    cell.isFirstInSection = { return $0.item == 0 }
                    cell.isLastInSection = { [unowned collectionView] in
                        let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                        return $0.item == numberOfItems - 1
                    }
                    return cell
                default: return nil
                }
            }
        return dataSource
    }
}

private extension NSCollectionLayoutSection {
    static var methodsSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(56)
        )
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        
        return section
    }
}
