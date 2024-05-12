import UIKit
import TKUIKit

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
  
  var didTapChangeCountryButton: (() -> Void)?
  
  // MARK: - Layout
  
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
    header.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 0,
      trailing: 16
    )
    
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
  private lazy var paymentMethodCellConfiguration = UICollectionView.CellRegistration<SelectionCollectionViewCell, SelectionCollectionViewCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
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
      customView.amountInputView.amountTextField.becomeFirstResponder()
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
    guard let animationDuration = notification.keyboardAnimationDuration,
          let keyboardHeight = notification.keyboardSize?.height
    else {
      return
    }
    
    let collectionViewBottomInset = keyboardHeight + customView.continueButton.bounds.height
    let continueButtonTranslatedY = -keyboardHeight + view.safeAreaInsets.bottom
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = collectionViewBottomInset
      self.customView.continueButton.transform = CGAffineTransform(translationX: 0, y: continueButtonTranslatedY)
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = 0
      self.customView.continueButton.transform = .identity
    }
  }
}

// MARK: - Setup

private extension BuySellViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    customView.collectionView.backgroundColor = .Background.page
    
    customView.amountInputView.backgroundColor = .Background.content
    customView.amountInputView.amountTokenTitleLabel.textColor = .Text.secondary
    customView.amountInputView.convertedAmountLabel.textColor = .Text.secondary
    customView.amountInputView.convertedCurrencyLabel.textColor = .Text.secondary
    customView.amountInputView.minAmountLabel.textColor = .Text.tertiary
    
    customView.amountInputView.amountTextField.delegate = viewModel.buySellAmountTextFieldFormatter
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
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      if let amountModel = model.amount {
        customView.amountInputView.isHidden = false
        customView.amountInputView.amountTextField.text = amountModel.text
        customView.amountInputView.amountTokenTitleLabel.text = amountModel.token.title
        customView.amountInputView.minAmountLabel.text = "Min. amount: \(amountModel.minimum) \(amountModel.token.title)"
      } else {
        customView.amountInputView.isHidden = true
      }
      
      customView.amountInputView.convertedAmountLabel.text = model.fiatAmount.converted
      customView.amountInputView.convertedCurrencyLabel.text = model.fiatAmount.currency.rawValue
      
      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
      customView.continueButton.configuration.isEnabled = model.button.isEnabled
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
    }
    
    viewModel.didUpdateCountryCode = { [weak self] countryCode in
      self?.customView.changeCountryButton.configuration.content.title = .plainString(countryCode)
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
    customView.amountInputView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.changeCountryButton.configuration.action = { [weak self] in
      self?.didTapChangeCountryButton?()
    }
    
    customView.tabButtonsContainerView.itemDidSelect = {[weak viewModel] itemId in
      let operation: BuySellItem.Operation = itemId == 0 ? .buy : .sell
      viewModel?.didChangeOperation(operation)
    }
    
    customView.amountInputView.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0 ?? "")
    }
  }
  
  func selectFirstItemCell<T: Hashable>(snapshot: NSDiffableDataSourceSnapshot<T, AnyHashable>,
                                        items: [SelectionCollectionViewCell.Configuration],
                                        inSection section: T) {
    guard !items.isEmpty, let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: section) else {
      return
    }
    
    let selectedIndexPath = IndexPath(row: 0, section: sectionIndex)
    let selectionClosure = items[0].selectionClosure
    
    customView.collectionView.performBatchUpdates(nil) { [weak self] _ in
      self?.customView.collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: .top)
      selectionClosure?()
    }
  }
  
  @objc func resignGestureAction() {
    customView.amountInputView.amountTextField.resignFirstResponder()
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
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(.paymentMethodCellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(.paymentMethodCellHeight)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 16,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
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
