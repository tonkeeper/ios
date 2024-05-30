import UIKit
import TKLocalize
import TKUIKit

final class OperatorSelectionViewController: GenericViewViewController<OperatorSelectionView> {
  typealias CurrencyShimmerView = TKCollectionViewSupplementaryContainerView<OperatorSelectionCurrencyShimmerView>
  typealias ListShimmerView = TKCollectionViewSupplementaryContainerView<OperatorsListShimmerView>
  
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
        case .currencyShimmer:
          return .currencyShimmerSection
        case .itemsShimmer:
          return .listShimmerSection
        }
      },
      configuration: configuration
    )
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  
  private lazy var currencyCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
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
    title = TKLocales.Buy.transaction_operator
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
    
    customView.collectionView.register(
      CurrencyShimmerView.self,
      forSupplementaryViewOfKind: .currencyShimmerSectionFooterElementKind,
      withReuseIdentifier: CurrencyShimmerView.reuseIdentifier
    )
    customView.collectionView.register(
      ListShimmerView.self,
      forSupplementaryViewOfKind: .listShimmerSectionFooterElementKind,
      withReuseIdentifier: ListShimmerView.reuseIdentifier
    )
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: true, completion: {
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
      collectionView: customView.collectionView) { [weak self, listItemCellConfiguration, currencyCellConfiguration] collectionView, indexPath, itemIdentifier in
        guard let self else { return nil }

        switch itemIdentifier {
        case let model as OperatorSelectionListModel:
          switch model.type {
          case .currency:
            let cell = collectionView.dequeueConfiguredReusableCell(
              using: currencyCellConfiguration,
              for: indexPath,
              item: model.configuration
            )
            return cell
          case .transactionOperator:
            let cell = collectionView.dequeueConfiguredReusableCell(
              using: listItemCellConfiguration,
              for: indexPath,
              item: model.configuration
            )
            cell.accessoryViews = self.createAccessoryViews()
            cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
            return cell
          }
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .currencyShimmer:
        let shimmerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: CurrencyShimmerView.reuseIdentifier,
          for: indexPath
        )
        (shimmerView as? CurrencyShimmerView)?.contentView.startAnimation()
        return shimmerView
      case .itemsShimmer:
        let shimmerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: ListShimmerView.reuseIdentifier,
          for: indexPath
        )
        (shimmerView as? ListShimmerView)?.contentView.startAnimation()
        return shimmerView
      default:
        return nil
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
    case let model as OperatorSelectionListModel:
      model.configuration.selectionClosure?()
    default:
      return
    }
  }
}

private extension String {
  static let currencyShimmerSectionFooterElementKind = "CurrencyShimmerSectionFooterElementKind"
  static let listShimmerSectionFooterElementKind = "ListShimmerSectionFooterElementKind"
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
  
  static var currencyShimmerSection: NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                                        heightDimension: .absolute(1)))
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(1)),
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(56)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .currencyShimmerSectionFooterElementKind,
      alignment: .top
    )
    section.boundarySupplementaryItems = [footer]
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 0,
      bottom: 16,
      trailing: 0
    )
    
    return section
  }
  
  static var listShimmerSection: NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .init(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(1))
    )
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(1)),
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(228)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .listShimmerSectionFooterElementKind,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
    
    return section
  }
}
