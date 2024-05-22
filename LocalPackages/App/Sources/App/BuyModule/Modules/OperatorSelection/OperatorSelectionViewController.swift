import UIKit
import TKLocalize
import TKUIKit

final class OperatorSelectionViewController: GenericViewViewController<OperatorSelectionView> {
  
  // MARK: - Module
  
  private let viewModel: OperatorSelectionViewModel
  
  // MARK: - List
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .currency:
          return .currencySection
        case .items:
          return .operatorSection
        }
      },
      configuration: configuration
    )
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
  // MARK: - Init

  init(viewModel: OperatorSelectionViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    setupViewEvents()
    viewModel.viewDidLoad()
  }
  
}

// MARK: - Private

private extension OperatorSelectionViewController {
  func setup() {
    title = "Operator"
    view.backgroundColor = .Background.page
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content.title = .plainString(TKLocales.Actions.continue_action)
    continueButtonConfiguration.isEnabled = false
    customView.continueButton.configuration = continueButtonConfiguration
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false, completion: {
      })
    }
    
    viewModel.didUpdateSelection = { [weak self] isSelected in
      self?.customView.continueButton.configuration.isEnabled = isSelected
    }
  }
  
  func setupViewEvents() {
    customView.continueButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapContinueButton()
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<OperatorSelectionSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<OperatorSelectionSection, AnyHashable>(
      collectionView: customView.collectionView) { [weak self, listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
        guard let self else { return nil }

        switch itemIdentifier {
        case let listCellConfiguration as TKUIListItemCell.Configuration:
          let cell = collectionView.dequeueConfiguredReusableCell(using: listItemCellConfiguration, for: indexPath, item: listCellConfiguration)
          if listCellConfiguration.id != viewModel.currencyCellId {
            cell.accessoryViews = self.createAccessoryViews()
            cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
          }
          
          return cell
        default: return nil
        }
      }
    
    return dataSource
  }
  
  func createSelectionAccessoryViews() -> [UIView] {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.contentPadding.right = 16
    configuration.iconTintColor = .Accent.blue
    configuration.content.icon = .TKUIKit.Icons.Size28.radioSelected
    let button = TKButton(configuration: configuration)
    button.isUserInteractionEnabled = false
    return [button]
  }
  
  func createAccessoryViews() -> [UIView] {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.contentPadding.right = 16
    configuration.iconTintColor = .Button.tertiaryBackground
    configuration.content.icon = .TKUIKit.Icons.Size28.radio
    let button = TKButton(configuration: configuration)
    button.isUserInteractionEnabled = false
    return [button]
  }
}

extension OperatorSelectionViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    switch item {
    case let model as TKUIListItemCell.Configuration:
      model.selectionClosure?()
    default:
      return
    }
  }
}

private extension NSCollectionLayoutSection {
  static var currencySection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(56)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(56)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return section
  }
  
  static var operatorSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return section
  }
}
