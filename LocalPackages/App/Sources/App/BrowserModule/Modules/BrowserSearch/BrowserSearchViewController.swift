import UIKit
import TKUIKit
import TKLocalize

final class BrowserSearchViewController: GenericViewViewController<BrowserSearchView>, KeyboardObserving {
  private let viewModel: BrowserSearchViewModel
  
  private lazy var dataSource = createDataSource()
  
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
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    item.onSelection()
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
    dataSource.snapshot().itemIdentifiers.first?.onSelection()
  }
  
  private func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [weak dataSource] sectionIndex, _ in
        guard let dataSource else { return nil }
        let snapshotSection = dataSource.snapshot().sectionIdentifiers[sectionIndex]
        
        switch snapshotSection {
        case .dapps:
          let sectionLayout: NSCollectionLayoutSection = .listItemsSection
          sectionLayout.contentInsets.bottom = 16
          return sectionLayout
        case .suggests:
          let sectionLayout: NSCollectionLayoutSection = .listItemsSection
          sectionLayout.contentInsets.bottom = 16
          
          let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(32)
          )
          let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
          )
          sectionLayout.boundarySupplementaryItems.append(header)
          
          return sectionLayout
        }
      },
      configuration: configuration
    )
    return layout
  }

  func createDataSource() -> BrowserSearch.DataSource {
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    let dataSource = BrowserSearch.DataSource(
      collectionView: customView.collectionView
    ) { collectionView, indexPath, itemIdentifier in
      let cell = collectionView.dequeueConfiguredReusableCell(
        using: listCellRegistration,
        for: indexPath,
        item: itemIdentifier.configuration)
      cell.isHighlighted = itemIdentifier.isHighlighted
      return cell
    }

    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath in
      guard let dataSource else { return nil }
      guard let section = dataSource.snapshot().sectionIdentifiers[safe: indexPath.section] else {
        return nil
      }
      
      switch section {
      case .dapps:
        return nil
      case let .suggests(headerModel):
        let view: BrowserSearchListSectionHeaderView = collectionView.dequeueReusableHeaderView(for: indexPath)
        view.configure(model: headerModel)
        return view
      }
    }
    
    return dataSource
  }
}

