import UIKit
import TKUIKit
import TKCoordinator

final class StakingConfirmationViewController: GenericViewViewController<StakingConfirmationView>, ScrollViewController, UICollectionViewDelegate {
    private let viewModel: StakingConfirmationViewModel
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [dataSource] sectionIndex, _ in .infoSection },
            configuration: configuration
        )
        return layout
    }()
    
    private lazy var dataSource = createDataSource()
    
    private lazy var infoCellConfiguration = UICollectionView.CellRegistration<StakingConfirmationCell, StakingConfirmationCell.Model> { [weak self]
        cell, indexPath, itemIdentifier in
        cell.configure(model: itemIdentifier)
    }
    
    private lazy var titleCellConfiguration = UICollectionView.CellRegistration<StakingConfirmationTitleCell, StakingConfirmationTitleCell.Model> { [weak self]
        cell, indexPath, itemIdentifier in
        cell.configure(model: itemIdentifier)
    }
    
    init(viewModel: StakingConfirmationViewModel) {
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
    
    func scrollToTop() {}
}

private extension StakingConfirmationViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        
        customView.collectionView.register(
            StakingOptionsCell.self,
            forCellWithReuseIdentifier: StakingOptionsCell.reuseIdentifier
        )
        customView.collectionView.register(
            StakingConfirmationTitleCell.self,
            forCellWithReuseIdentifier: StakingConfirmationTitleCell.reuseIdentifier
        )
        
        customView.sliderView.didSlide = { [weak self] in
            guard let self else { return }
            if self.customView.successFlowView.state == .content {
                self.viewModel.prepareStaking()
            }
            self.customView.successFlowView.state = .loading
        }
    }
    
    func setupBindings() {
        viewModel.didUpdateModel = { [weak dataSource] model in
            guard let dataSource else { return }
            var snapshot = dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections(model.sections)
            for section in model.sections {
                switch section {
                case .info(items: let items):
                    snapshot.appendItems(items, toSection: section)
                case .title(item: let item):
                    snapshot.appendItems([item], toSection: section)
                }
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
        
        viewModel.didUpdateButtons = { [weak self] in
            self?.customView.successFlowView.state = $0
        }
    }
    
    func createDataSource() -> UICollectionViewDiffableDataSource<StakingConfirmationSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<StakingConfirmationSection, AnyHashable>(
            collectionView: customView.collectionView) { [infoCellConfiguration, titleCellConfiguration] collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let configuration as StakingConfirmationCell.Model:
                    let cell = collectionView.dequeueConfiguredReusableCell(using: infoCellConfiguration, for: indexPath, item: configuration)
                    cell.isFirstInSection = { return $0.item == 0 }
                    cell.isLastInSection = { [unowned collectionView] in
                      let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                      return $0.item == numberOfItems - 1
                    }
                    return cell
                case let configuration as StakingConfirmationTitleCell.Model:
                    let cell = collectionView.dequeueConfiguredReusableCell(using: titleCellConfiguration, for: indexPath, item: configuration)
                    return cell
                default: return nil
                }
            }
        
        return dataSource
    }
}

private extension NSCollectionLayoutSection {
    static var infoSection: NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(56)
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        
        return section
    }
}
