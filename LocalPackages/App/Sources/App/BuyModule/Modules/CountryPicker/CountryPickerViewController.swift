import UIKit
import TKUIKit
import TKCore

final class CountryPickerViewController: GenericViewViewController<CountryPickerView>, TKBottomSheetScrollContentViewController {
  typealias Item = TKUIListItemCell.Configuration
  typealias Section = CountryPickerSection
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  typealias CellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>
  
  var didSelectCountry: ((SelectedCountry) -> Void)?
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(
      title: .title(
        title: "Choose your country",
        subtitle: nil
      )
    )
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    return scrollView.contentSize.height
  }
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - Dependencies
  
  private let selectedCountry: SelectedCountry
  private let countriesProvider: CountriesProvider
  
  // MARK: - Init
  
  init(selectedCountry: SelectedCountry,
       countriesProvider: CountriesProvider) {
    self.selectedCountry = selectedCountry
    self.countriesProvider = countriesProvider
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.allowsMultipleSelection = true
    customView.collectionView.delegate = self
    
    let countries = countriesProvider.countries
    updateList(countries: countries, locale: .current)
  }
}

private extension CountryPickerViewController {
  func createDataSource() -> DataSource {
    let cellConfiguration = CellConfiguration {
      [weak collectionView = self.customView.collectionView] cell, indexPath, identifier in
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      cell.configure(configuration: identifier)
      cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
    }
    
    let dataSource = DataSource(collectionView: customView.collectionView) {
      collectionView,
      indexPath,
      itemIdentifier in
      collectionView.dequeueConfiguredReusableCell(
        using: cellConfiguration,
        for: indexPath,
        item: itemIdentifier
      )
    }
    
    return dataSource
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, _ in
      let itemLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(56)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
      
      let groupLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(56)
      )
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupLayoutSize,
        subitems: [item]
      )
      
      let layoutSection = NSCollectionLayoutSection(group: group)
      layoutSection.contentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: 16,
        trailing: 16
      )
      
      return layoutSection
    }, configuration: configuration)
    
    return layout
  }
  
  func updateList(countries: [Country], locale: Locale) {
    var snapshot = Snapshot()
    
    var recentSectionItems = [TKUIListItemCell.Configuration]()
    var selectedItems = [TKUIListItemCell.Configuration]()
    
    let auto = countries.first(where: { $0.alpha2 == locale.regionCode })
    if let auto {
      let item = mapCountry(
        id: "auto",
        itemTitle: "Auto",
        itemSubtitle: auto.en,
        icon: auto.flag) { [weak self] in
          self?.didSelectCountry?(.auto)
        }
      recentSectionItems.append(item)
      if case .auto = selectedCountry {
        selectedItems.append(item)
      }
    }
    let all = mapCountry(
      id: "all",
      itemTitle: "All Regions",
      itemSubtitle: nil,
      icon: "🌍") { [weak self] in
        self?.didSelectCountry?(.all)
      }
    recentSectionItems.append(all)
    if case .all = selectedCountry {
      selectedItems.append(all)
    }
    
    if case .country(let countryCode) = selectedCountry, let country = countries.first(where: { $0.alpha2 == countryCode }) {
      let countryRecent = mapCountry(
        id: "countryRecent",
        itemTitle: country.en,
        itemSubtitle: nil,
        icon: country.flag) { [weak self] in
          self?.didSelectCountry?(.country(countryCode: country.alpha2))
        }
      recentSectionItems.append(countryRecent)
      selectedItems.append(countryRecent)
    }
    
    snapshot.appendSections([.recent])
    snapshot.appendItems(recentSectionItems, toSection: .recent)
    
    snapshot.appendSections([.all])
    countries.forEach { country in
      let item = mapCountry(
        id: country.alpha2,
        itemTitle: country.en,
        itemSubtitle: nil,
        icon: country.flag) { [weak self] in
          self?.didSelectCountry?(.country(countryCode: country.alpha2))
        }
      if case .country(let countryCode) = self.selectedCountry,
         country.alpha2 == countryCode {
        selectedItems.append(item)
      }
      snapshot.appendItems([item], toSection: .all)
    }
    
    dataSource.apply(snapshot, animatingDifferences: false) { [weak self, weak dataSource] in
      guard let self, let dataSource else { return }
      selectedItems
        .compactMap { dataSource.indexPath(for:$0) }
        .forEach {
          self.customView.collectionView.selectItem(at: $0, animated: false, scrollPosition: [])
        }
    }
    
  }
  
  func mapCountry(id: String, 
                  itemTitle: String,
                  itemSubtitle: String?,
                  icon: String,
                  selectionClosure: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .emoji(
        TKUIListItemEmojiIconView.Configuration(
          emoji: icon,
          backgroundColor: .clear,
          size: 28
        )
      ),
      alignment: .center
    )
    
    let title = NSMutableAttributedString()
    let titleFormatted = "\(itemTitle) ".withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    title.append(titleFormatted)
    
    if let itemSubtitle {
      let subtitleFormatted = itemSubtitle.withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      title.append(subtitleFormatted)
    }
  
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: nil,
      description: nil,
      descriptionNumberOfLines: 0
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: leftItemConfiguration,
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionClosure
    )
  }
  
  func createSelectionAccessoryViews() -> [UIView] {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.contentPadding.right = 16
    configuration.iconTintColor = .Accent.blue
    configuration.content.icon = .TKUIKit.Icons.Size28.donemarkOutline
    let button = TKButton(configuration: configuration)
    button.isUserInteractionEnabled = false
    return [button]
  }
}

extension CountryPickerViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    dataSource.snapshot()
      .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
      .selectionClosure?()
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    dataSource.snapshot()
      .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
      .selectionClosure?()
  }
}
