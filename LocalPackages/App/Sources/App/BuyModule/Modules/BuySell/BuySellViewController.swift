import UIKit
import TKUIKit

enum BuySellSection: Hashable {
  case paymentMethodItems
}

final class BuySellViewController: GenericViewViewController<BuySellView>, KeyboardObserving {
  
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
  private lazy var paymentMethodCellConfiguration = UICollectionView.CellRegistration<PaymentMethodItemCell, PaymentMethodItemCell.Configuration> { [weak self]
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
        case let cellConfiguration as PaymentMethodItemCell.Configuration:
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
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    setupViewEvents()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    registerForKeyboardEvents()
    customView.amountInputView.amountTextField.becomeFirstResponder()
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = keyboardHeight
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = 0
    }
  }
}

// MARK: - Setup

private extension BuySellViewController {
  func setup() {
    title = "Buy Sell"
    view.backgroundColor = .Background.page
    
    customView.collectionView.backgroundColor = .Background.page
    
    customView.amountInputView.backgroundColor = .Background.content
    customView.amountInputView.amountTokenTitleLabel.textColor = .Text.secondary
    customView.amountInputView.convertedAmountLabel.textColor = .Text.secondary
    customView.amountInputView.convertedCurrencyLabel.textColor = .Text.secondary
    customView.amountInputView.minAmountLabel.textColor = .Text.tertiary
    
    customView.amountInputView.amountTextField.delegate = viewModel.buySellAmountTextFieldFormatter
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: .amountInputHeaderElementKind,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false
    
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
      } else {
        customView.amountInputView.isHidden = true
      }
      
      customView.amountInputView.convertedAmountLabel.text = model.balance.converted
      customView.amountInputView.convertedCurrencyLabel.text = model.balance.currency.rawValue
      
      customView.amountInputView.minAmountLabel.text = "Min. amount: 50 TON"
      
      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
      customView.continueButton.configuration.isEnabled = model.button.isEnabled
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
    }
    
    viewModel.didUpdatePaymentMethodItems = { [weak self, weak dataSource] paymentMethodItems in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .paymentMethodItems))
      snapshot.appendItems(paymentMethodItems, toSection: .paymentMethodItems)
      dataSource.apply(snapshot,animatingDifferences: false)
      
      guard !paymentMethodItems.isEmpty,
            let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: .paymentMethodItems)
      else {
        return
      }
      
      let selectedIndexPath = IndexPath(row: 0, section: sectionIndex)
      self?.updateCollectionViewSelection(at: selectedIndexPath)
    }
  }
  
  func updateCollectionViewSelection(at selectedIndexPath: IndexPath) {
    customView.collectionView.performBatchUpdates(nil) { [weak collectionView = customView.collectionView] _ in
      collectionView?.selectItem(at: selectedIndexPath, animated: false, scrollPosition: .top)
    }
  }
  
  func setupViewEvents() {
    customView.amountInputView.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0 ?? "")
    }
  }
}

extension BuySellViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    if let model = item as? PaymentMethodItemCell.Configuration {
      viewModel.didSelectPaymentMethodId(model.id)
    }
  }
}

private extension String {
  static let amountInputHeaderElementKind = "AmountInputHeaderElementKind"
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

private extension CGFloat {
  static let paymentMethodCellHeight: CGFloat = 56
}
