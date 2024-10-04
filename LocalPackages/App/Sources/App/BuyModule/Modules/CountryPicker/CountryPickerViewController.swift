import UIKit
import TKUIKit
import TKCore
import KeeperCore

final class CountryPickerViewController: GenericViewViewController<CountryPickerView>, KeyboardObserving {
  typealias Item = TKUIListItemCell.Configuration
  typealias Section = CountryPickerSection
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  typealias CellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>
  
  var didSelectCountry: ((SelectedCountry) -> Void)?
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - State
  
  private var countries = [Country]() {
    didSet {
      updateList(countries: countries, locale: .current, animated: false)
    }
  }
  private var isSearching: Bool = false {
    didSet {
      updateList(countries: countries, locale: .current, animated: true)
    }
  }
  private var searchInput: String? {
    didSet {
      guard isSearching else { return }
      updateList(countries: countries, locale: .current, animated: false)
    }
  }
  
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
    
    customView.topBar.title = "Choose your country"
    customView.topBar.button.configuration.action = { [weak self] in
      self?.dismiss(animated: true)
    }
    customView.searchBar.isCancelButtonOnEdit = true
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.allowsMultipleSelection = true
    customView.collectionView.delegate = self
    
    self.countries = countriesProvider.countries
    
    customView.searchBar.placeholder = "Search"
    customView.searchBar.textField.addTarget(self, action: #selector(didBeginSearch), for: .editingDidBegin)
    customView.searchBar.textField.addTarget(self, action: #selector(didEndSearch), for: .editingDidEnd)
    customView.searchBar.textField.addTarget(self, action: #selector(didEdit), for: .editingChanged)
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.hideTopBar()
      self.customView.collectionView.contentInset.bottom = keyboardHeight
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.showTopBar()
      self.customView.collectionView.contentInset.bottom = 0
    }
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
  
  func updateList(countries: [Country], locale: Locale, animated: Bool) {
    var snapshot = Snapshot()
    
    var recentSectionItems = [TKUIListItemCell.Configuration]()
    var selectedItems = [TKUIListItemCell.Configuration]()
    if !isSearching {
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
      
    }
    snapshot.appendSections([.all])
    let filteredCountries: [Country] = {
      guard isSearching else {
        return countries
      }
      if let searchInput, !searchInput.isEmpty {
        return countries.filter { country in
          country.en.lowercased().contains(searchInput.lowercased()) || country.ru.lowercased().contains(searchInput.lowercased())
        }
      } else {
        return countries
      }
    }()
    
    filteredCountries.forEach { country in
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
    
    dataSource.apply(snapshot, animatingDifferences: animated) { [weak self, weak dataSource] in
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
  
  @objc func didBeginSearch() {
    isSearching = true
  }
  
  @objc func didEndSearch() {
    searchInput = nil
    customView.searchBar.textField.text = nil
    isSearching = false
  }
  
  @objc func didEdit() {
    searchInput = customView.searchBar.textField.text
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
