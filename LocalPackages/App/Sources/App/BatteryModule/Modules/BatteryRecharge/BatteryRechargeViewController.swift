import UIKit
import TKUIKit

final class BatteryRechargeViewController: GenericViewViewController<BatteryRechargeView>, KeyboardObserving {
  private let viewModel: BatteryRechargeViewModel
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - Title
  
  private let titleLabel = UILabel()
  
  // MARK: - TokenPicker
  
  private let tokenPickerButton = TokenPickerButton()
  
  // MARK: - Custom input
  
  private let amountInputViewController: AmountInputViewController
  private let continueButton = TKButton()
  
  // MARK: - Promocode
  
  private let promocodeViewController: BatteryPromocodeInputViewController
  
  // MARK: - Recipient
  
  private let recipientViewController: RecipientInputViewController
  
  // MARK: - Init
  
  init(viewModel: BatteryRechargeViewModel,
       amountInputViewController: AmountInputViewController,
       promocodeViewController: BatteryPromocodeInputViewController,
       recipientViewController: RecipientInputViewController) {
    self.viewModel = viewModel
    self.amountInputViewController = amountInputViewController
    self.promocodeViewController = promocodeViewController
    self.recipientViewController = recipientViewController
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let keyboardHeight = notification.keyboardSize?.height else { return }
    customView.collectionView.contentInset.bottom = keyboardHeight
    if amountInputViewController.isInputEditing {
      customView.collectionView.scrollVerticallyToView(amountInputViewController.view, animated: true)
    } else if promocodeViewController.isInputEditing {
      customView.collectionView.scrollVerticallyToView(promocodeViewController.view, animated: true)
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    customView.collectionView.contentInset.bottom = 0
    customView.collectionView.contentInset.bottom = view.safeAreaInsets.bottom + 16
  }
}

private extension BatteryRechargeViewController {
  func setup() {
    tokenPickerButton.contentPadding = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 8)
    tokenPickerButton.category = .secondary
    
    setupNavigationBar()
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.register(
      TKContainerCollectionViewCell.self,
      forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
    )
    
    recipientViewController.didUpdateText = { [weak self] in
      self?.customView.collectionView.collectionViewLayout.invalidateLayout()
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
    viewModel.didUpdateTitle = { [weak self] title in
      self?.titleLabel.attributedText = title.withTextStyle(.h3, color: .Text.primary)
    }
    viewModel.didUpdateContinueButtonConfiguration = { [weak self] in
      self?.continueButton.configuration = $0
    }
    viewModel.didUpdateTokenPickerButtonConfiguration = { [weak self] in
      self?.tokenPickerButton.configuration = $0
    }
    viewModel.didUpdateTokenPickerAction = { [weak self] action in
      self?.tokenPickerButton.didTap = {
        action()
      }
    }
  }
  
  private func setupNavigationBar() {
    customView.navigationBar.leftViews = [titleLabel]
    
    customView.navigationBar.rightViews = [
      tokenPickerButton,
      TKUINavigationBar.createCloseButton { [weak self] in
        self?.dismiss(animated: true)
      }
    ]
  }
  
  func createDataSource() -> BatteryRecharge.DataSource {
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    
    let dataSource = BatteryRecharge.DataSource(
      collectionView: customView.collectionView
    ) { [weak self]
      collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
      guard let self else { return nil }
      switch itemIdentifier {
      case .rechargeOption(let item):
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listCellRegistration,
          for: indexPath,
          item: item.listCellConfiguration)
        cell.defaultAccessoryViews = [createRadioButtonAccessoryView(isEnable: item.isEnable,
                                                                     isSelected: false)]
        cell.selectionAccessoryViews = [createRadioButtonAccessoryView(isEnable: item.isEnable,
                                                                       isSelected: true)]
        cell.leftAccessoryViews = [self.createAccessoryBatteryView(item: item)]
        return cell
      case .customInput:
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier, 
          for: indexPath
        )
        self.addChild(amountInputViewController)
        (cell as? TKContainerCollectionViewCell)?.setContentView(amountInputViewController.view)
        amountInputViewController.didMove(toParent: self)
        return cell
      case .continueButton:
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
          for: indexPath
        )
        (cell as? TKContainerCollectionViewCell)?.setContentView(continueButton)
        return cell
      case .promocode:
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
          for: indexPath
        )
        self.addChild(promocodeViewController)
        (cell as? TKContainerCollectionViewCell)?.setContentView(promocodeViewController.view)
        promocodeViewController.didMove(toParent: self)
        return cell
      case .recipient:
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
          for: indexPath
        )
        self.addChild(recipientViewController)
        (cell as? TKContainerCollectionViewCell)?.setContentView(recipientViewController.view)
        recipientViewController.didMove(toParent: self)
        return cell
      }
    }
    return dataSource
  }
  
  func createRadioButtonAccessoryView(isEnable: Bool, isSelected: Bool) -> UIView {
    let radioButton = RadioButton()
    radioButton.padding.right = 16
    radioButton.size = 28
    radioButton.tintColors = [.selected: .Button.primaryBackground, .deselected: .Icon.tertiary]
    radioButton.isEnabled = isEnable
    radioButton.isSelected = isSelected
    radioButton.isUserInteractionEnabled = false
    return radioButton
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, _ in
      let itemLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(96)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
      
      let groupLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(96)
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
  
  private func createAccessoryBatteryView(item: BatteryRecharge.RechargeOptionItem) -> UIView  {
    let batteryView = BatteryView(size: .size44)
    batteryView.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
    batteryView.state = item.batteryViewState
    return batteryView
  }
}

extension BatteryRechargeViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .rechargeOption(let item):
      item.onSelection()
    default: break
    }
  }

  func collectionView(_ collectionView: UICollectionView,
                      shouldSelectItemAt indexPath: IndexPath) -> Bool {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .rechargeOption(let item):
      return item.isEnable
    case .customInput, .continueButton, .promocode, .recipient:
      return false
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .rechargeOption(let item):
      return item.isEnable
    case .customInput, .continueButton, .promocode, .recipient:
      return false
    }
  }
}

extension NSDiffableDataSourceSnapshot {
  func getItem(at indexPath: IndexPath) -> ItemIdentifierType? {
    guard sectionIdentifiers.count > indexPath.section else { return nil }
    let section = sectionIdentifiers[indexPath.section]
    let sectionItemIdentifiers = itemIdentifiers(inSection: section)
    guard sectionItemIdentifiers.count > indexPath.item else { return nil }
    return sectionItemIdentifiers[indexPath.item]
  }
}
