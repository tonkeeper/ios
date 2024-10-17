import UIKit
import TKUIKit
import TKLocalize

final class BrowserSearchViewController: GenericViewViewController<BrowserSearchView>, KeyboardObserving {
  
  typealias DataSource = UICollectionViewDiffableDataSource<BrowserSearchSection, TKUIListItemCell.Configuration>

  private let viewModel: BrowserSearchViewModel
  
  private lazy var dataSource = createDataSource()
  
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in
      return ip.item == 0
    }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
  init(viewModel: BrowserSearchViewModel) {
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
    setupViewActions()
    viewModel.viewDidLoad()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    _ = customView.searchBar.becomeFirstResponder()
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height,
    let curve = notification.keyboardAnimationCurve else { return }
    customView.keyboardHeight = keyboardHeight
    UIViewPropertyAnimator(duration: animationDuration, curve: curve) {
      self.view.layoutIfNeeded()
    }
    .startAnimation()
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let curve = notification.keyboardAnimationCurve else { return }
    customView.keyboardHeight = 0
    UIViewPropertyAnimator(duration: animationDuration, curve: curve) {
      self.view.layoutIfNeeded()
    }
    .startAnimation()
  }
}

// MARK: -  UICollectionViewDelegate

extension BrowserSearchViewController: UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView,
                      didSelectItemAt indexPath: IndexPath) {
    guard let section = dataSource.snapshot().sectionIdentifiers[safe: indexPath.section],
          let item = dataSource.snapshot().itemIdentifiers(inSection: section)[safe: indexPath.item] else {
      return
    }

    item.selectionClosure?()
  }
}

private extension BrowserSearchViewController {

  func setup() {
    title = TKLocales.Browser.Search.title
    
    let cancelButton = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
    cancelButton.configuration.padding.top = 4
    cancelButton.configuration.padding.bottom = 4
    cancelButton.configuration.content = TKButton.Configuration.Content(
      title: .plainString(
        TKLocales.Actions.cancel
      )
    )
    cancelButton.configuration.action = { [weak self] in
      self?.dismiss(animated: true)
    }
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
    
    customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
    customView.collectionView.registerHeaderViewClass(BrowserSearchListSectionHeaderView.self)
    customView.collectionView.delegate = self
  }
  
  func setupBindings() {
    viewModel.didUpdateEmptyText = { [weak self] in
      self?.customView.emptyLabel.attributedText = $0
    }
    
    viewModel.didUpdateSnapshot = { [weak self] in
      self?.customView.emptyView.isHidden = !$0.itemIdentifiers.isEmpty
      self?.dataSource.apply($0)
    }
  }
  
  func setupViewActions() {
    customView.searchBar.textField.addTarget(
      self,
      action: #selector(didEditSearch),
      for: .editingChanged
    )
    
    customView.searchBar.textField.addTarget(
      self,
      action: #selector(didTapReturnButton),
      for: .primaryActionTriggered
    )
  }
  
  @objc
  func didEditSearch() {
    viewModel.searchInput(customView.searchBar.textField.text ?? "")
  }
  
  @objc
  func didTapReturnButton() {
    viewModel.goButtonPressed()
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.interSectionSpacing = 16
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: {
      [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
      guard let self = self else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[sectionIndex]
      switch section {
      case .apps:
        return appsSectionLayout(
          snapshot: snapshot,
          section: section,
          environment: environment
        )
      case .newSearch:
        return searchSectionLayout(
          snapshot: snapshot,
          section: section,
          environment: environment
        )
      }
    }, configuration: configuration)
    
    return layout
  }
  
  func appsSectionLayout(snapshot: NSDiffableDataSourceSnapshot<BrowserSearchSection, TKUIListItemCell.Configuration>,
                         section: BrowserSearchSection,
                         environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1),
      heightDimension: .absolute(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    
    let group: NSCollectionLayoutGroup
    
    if #available(iOS 16.0, *) {
      group = NSCollectionLayoutGroup.verticalGroup(
        with: groupSize,
        repeatingSubitem: item,
        count: 1
      )
    } else {
      group = NSCollectionLayoutGroup.vertical(
        layoutSize: groupSize,
        subitem: item,
        count: 1
      )
    }
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .init(top: 10, leading: 16, bottom: 16, trailing: 0)
    return section
  }

  func searchSectionLayout(snapshot: NSDiffableDataSourceSnapshot<BrowserSearchSection, TKUIListItemCell.Configuration>,
                           section: BrowserSearchSection,
                           environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let heightDimension: CGFloat = 48
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1),
      heightDimension: .absolute(heightDimension)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(heightDimension)
    )

    let group: NSCollectionLayoutGroup

    if #available(iOS 16.0, *) {
      group = NSCollectionLayoutGroup.verticalGroup(
        with: groupSize,
        repeatingSubitem: item,
        count: 1
      )
    } else {
      group = NSCollectionLayoutGroup.vertical(
        layoutSize: groupSize,
        subitem: item,
        count: 1
      )
    }

    let section = NSCollectionLayoutSection(group: group)
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(34)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: UICollectionView.elementKindSectionHeader,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    section.contentInsets = .init(top: 10, leading: 16, bottom: 16, trailing: 0)
    return section
  }

  func createDataSource() -> DataSource {
    let dataSource = DataSource(
      collectionView: customView.collectionView
    ) { [listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case let listCellConfiguration:
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listItemCellConfiguration,
          for: indexPath,
          item: listCellConfiguration
        )

        cell.backgroundColor = indexPath.item == 0 ? .Background.contentTint : .Background.content
        return cell
      }
    }

    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
      guard let section = dataSource.snapshot().sectionIdentifiers[safe: indexPath.section] else {
        return nil
      }

      switch section {
      case .apps:
        return nil
      case let .newSearch(headerModel):
        let view: BrowserSearchListSectionHeaderView = collectionView.dequeueReusableHeaderView(for: indexPath)
        view.configure(model: headerModel)
        return view
      }
    }

    return dataSource
  }
}

