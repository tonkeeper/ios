import UIKit
import TKUIKit
import KeeperCore

open class ModalViewController<View: UIView, NavigationBar: ModalNavigationBarView>: GenericViewViewController<View> {
  public let customNavigationBarView = NavigationBar()
  private var leftNavigationItemObserveToken: NSKeyValueObservation?
  private var rightNavigationItemObserveToken: NSKeyValueObservation?
  
  deinit {
    leftNavigationItemObserveToken = nil
    rightNavigationItemObserveToken = nil
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    
    setupNavigationBarView()
  }
  
  open func setupNavigationBarView() {
    navigationController?.setNavigationBarHidden(true, animated: false)
    
    customView.addSubview(customNavigationBarView)
    
    customNavigationBarView.snp.makeConstraints { make in
      make.left.right.top.equalTo(customView)
      make.height.equalTo(ModalNavigationBarView.defaultHeight)
    }
    
    setupNavigationItemObservation()
    
    updateLeftBarItem()
    updateRightBarItem()
  }
  
  private func setupNavigationItemObservation() {
    leftNavigationItemObserveToken = navigationItem.observe(\.leftBarButtonItem) { [weak self] item, _ in
      self?.updateLeftBarItem()
    }
    rightNavigationItemObserveToken = navigationItem.observe(\.rightBarButtonItem) { [weak self] item, _ in
      self?.updateRightBarItem()
    }
  }
  
  private func updateLeftBarItem() {
    guard let leftItem = navigationItem.leftBarButtonItem?.customView else { return }
    customNavigationBarView.setupLeftBarItem(configuration: .init(view: leftItem))
  }
  
  private func updateRightBarItem() {
    guard let rightItem = navigationItem.rightBarButtonItem?.customView else { return }
    customNavigationBarView.setupRightBarItem(configuration: .init(view: rightItem))
  }
}

enum BuySellSection: Hashable {
  case paymentMethodItems
}

final class BuySellViewController: ModalViewController<BuySellView, ModalNavigationBarView>, KeyboardObserving {
  
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  
  var didTapChangeCountryButton: (() -> Void)?
  
  // MARK: - List
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: .amountInputHeaderElementKind,
      alignment: .top
    )
    header.contentInsets = .amountInputHeaderContentInsets
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .paymentMethodItems:
          return .paymentMethodItemsSection
        }
      },
      configuration: configuration
    )
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var paymentMethodCellConfiguration: CellRegistration<SelectionCollectionViewCell> = createDefaultCellRegistration()
  
  lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    return gestureRecognizer
  }()
  
  private var isViewDidAppearFirstTime = false
  
  // MARK: - Dependencies
  
  private let viewModel: BuySellViewModel
  
  // MARK: - Init
  
  init(viewModel: BuySellViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupCollectionView()
    setupBindings()
    setupGestures()
    setupViewEvents()
    
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !isViewDidAppearFirstTime {
      customView.amountInputView.inputControl.amountTextField.becomeFirstResponder()
      isViewDidAppearFirstTime = true
    }
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.collectionView.contentInset.top = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.setupLeftBarItem(
      configuration: .init(
        view: customView.changeCountryButton,
        contentAlignment: .left
      )
    )
    
    customNavigationBarView.setupCenterBarItem(
      configuration: .init(
        view: customView.tabButtonsContainerView,
        containerHeight: .tabButtonsContainerViewHeight,
        containerAlignment: .bottom(0),
        contentAlignment: .center
      )
    )
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    guard let keyboardHeight = notification.keyboardSize?.height else { return }
    
    let contentInsetBottom = keyboardHeight + customView.continueButtonContainer.bounds.height - view.safeAreaInsets.bottom
    let buttonContainerTranslatedY = -keyboardHeight + view.safeAreaInsets.bottom
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = contentInsetBottom
      self.customView.continueButtonContainer.transform = CGAffineTransform(translationX: 0, y: buttonContainerTranslatedY)
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = 0
      self.customView.continueButtonContainer.transform = .identity
    }
  }
}

// MARK: - Setup

private extension BuySellViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    customView.collectionView.backgroundColor = .Background.page
    
    customView.amountInputView.backgroundColor = .Background.content
    customView.amountInputView.convertedAmountLabel.textColor = .Text.secondary
    customView.amountInputView.convertedCurrencyLabel.textColor = .Text.secondary
    customView.amountInputView.minAmountLabel.textColor = .Text.tertiary
    
    customView.amountInputView.inputControl.amountTextField.delegate = viewModel.textFieldFormatter
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: .amountInputHeaderElementKind,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.paymentMethodItems])
    dataSource.apply(snapshot,animatingDifferences: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateInputAmountText = { [weak customView] text in
      customView?.amountInputView.inputControl.amountTextField.text = text
    }
    
    viewModel.didUpdateCountryCode = { [weak self] countryCode in
      self?.customView.changeCountryButton.configuration.content.title = .plainString(countryCode ?? "🌍")
    }
    
    viewModel.didUpdatePaymentMethodItems = { [weak self] paymentMethodItems in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .paymentMethodItems))
      snapshot.appendItems(paymentMethodItems, toSection: .paymentMethodItems)
      dataSource.apply(snapshot,animatingDifferences: false)
      
      selectFirstItemCell(snapshot: snapshot, items: paymentMethodItems, inSection: .paymentMethodItems)
    }
  }
  
  func setupGestures() {
    customView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.changeCountryButton.configuration.action = { [weak self] in
      self?.didTapChangeCountryButton?()
    }
    
    customView.tabButtonsContainerView.itemDidSelect = { [weak viewModel] itemId in
      let operation: BuySellModel.Operation = itemId == 0 ? .buy : .sell
      viewModel?.didChangeOperation(operation)
    }
    
    customView.amountInputView.inputControl.didUpdateText = { [weak viewModel] text in
      guard let text else { return }
      viewModel?.didInputAmount(text)
    }
  }
  
  func selectFirstItemCell<T: Hashable>(snapshot: NSDiffableDataSourceSnapshot<T, AnyHashable>,
                                        items: [SelectionCollectionViewCell.Configuration],
                                        inSection section: T) {
    guard !items.isEmpty else { return }
    guard let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: section) else { return }
    
    let selectedIndexPath = IndexPath(row: 0, section: sectionIndex)
    let selectionClosure = items[0].selectionClosure
    
    customView.collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: [])
    selectionClosure?()
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<BuySellSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<BuySellSection, AnyHashable>(
      collectionView: customView.collectionView) { [paymentMethodCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as SelectionCollectionViewCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: paymentMethodCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak headerView = customView.amountInputView] collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case String.amountInputHeaderElementKind:
        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
          for: indexPath
        ) as? TKReusableContainerView
        view?.setContentView(headerView)
        return view
      default: return nil
      }
    }
    
    return dataSource
  }
  
  func createDefaultCellRegistration<T>() -> CellRegistration<T> {
    return CellRegistration<T> { [weak self]
      cell, indexPath, itemIdentifier in
      cell.configure(configuration: itemIdentifier)
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
    }
  }
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    let touchLocation = sender.location(in: customView.amountInputView)
    let isTapInTextField = customView.amountInputView.inputControl.frame.contains(touchLocation)
    
    guard !isTapInTextField else { return }
    
    customView.amountInputView.inputControl.amountTextField.resignFirstResponder()
  }
}

extension BuySellViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    guard let model = item as? SelectionCollectionViewCell.Configuration else { return }
    model.selectionClosure?()
  }
}

private extension NSCollectionLayoutSection {
  static var paymentMethodItemsSection: NSCollectionLayoutSection {
    return createSection(cellHeight: .paymentMethodCellHeight)
  }
  
  static func createSection(cellHeight: CGFloat,
                          contentInsets: NSDirectionalEdgeInsets = .defaultSectionInsets) -> NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cellHeight)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = contentInsets
    return section
  }
}

private extension String {
  static let amountInputHeaderElementKind = "AmountInputHeaderElementKind"
}

private extension CGFloat {
  static let paymentMethodCellHeight: CGFloat = 56
  static let tabButtonsContainerViewHeight: CGFloat = 53
}

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
  static let amountInputHeaderContentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
}
