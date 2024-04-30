import UIKit

open class TKCollectionController<Section: Hashable, Item: Hashable>: NSObject, UICollectionViewDelegate, UIScrollViewDelegate {
  public typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  
  typealias HeaderSupplementaryRegistration = UICollectionView.SupplementaryRegistration<CollectionViewSupplementaryContainerView>
  typealias FooterSupplementaryRegistration = UICollectionView.SupplementaryRegistration<CollectionViewSupplementaryContainerView>
  
  public var isSelectable: ((_ section: Section, _ index: Int) -> Bool)?
  public var isHighlightable: ((_ section: Section, _ index: Int) -> Bool)?
  public var isEditable: ((_ section: Section, _ index: Int) -> Bool)?
  public var didSelect: ((_ section: Section, _ index: Int) -> Void)?
  public var didReorder: ((CollectionDifference<Item>) -> Void)?
  public var didScroll: ((UIScrollView) -> Void)?
  
  public var isEditing: Bool {
    get { collectionView.isEditing }
    set {
      collectionView.isEditing = newValue
      reorderGesture.isEnabled = newValue
    }
  }
  
  public var supplementaryViewProvider: ((UICollectionView, String, IndexPath) -> UICollectionReusableView?)?
  
  private lazy var reorderGesture: UILongPressGestureRecognizer = {
    let gesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(handleReorderGesture(gesture:))
    )
    gesture.isEnabled = false
    return gesture
  }()
  
  public let dataSource: DataSource
  
  private let headerRegistration: HeaderSupplementaryRegistration
  private let footerRegistration: HeaderSupplementaryRegistration
  
  private let collectionView: UICollectionView
  private let cellProvider: (UICollectionView, IndexPath, Item) -> UICollectionViewCell?
  private let headerViewProvider: (() -> UIView)?
  private let footerViewProvider: (() -> UIView)?
  
  public init(collectionView: UICollectionView,
              cellProvider: @escaping (UICollectionView, IndexPath, Item) -> UICollectionViewCell?,
              headerViewProvider: (() -> UIView)? = nil,
              footerViewProvider: (() -> UIView)? = nil) {
    self.collectionView = collectionView
    self.cellProvider = cellProvider
    self.headerViewProvider = headerViewProvider
    self.footerViewProvider = footerViewProvider
    
    let headerRegistration = HeaderSupplementaryRegistration(
      elementKind: TKCollectionSupplementaryItem.header.kind,
      handler: { supplementaryView, elementKind, indexPath in
        supplementaryView.setContentView(headerViewProvider?())
      })
    self.headerRegistration = headerRegistration
    
    let footerRegistration = FooterSupplementaryRegistration(
      elementKind: TKCollectionSupplementaryItem.footer.kind,
      handler: { supplementaryView, elementKind, indexPath in
        supplementaryView.setContentView(footerViewProvider?())
      }
    )
    self.footerRegistration = footerRegistration
    
    self.dataSource = DataSource(collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
      let cell = cellProvider(collectionView, indexPath, itemIdentifier)
      (cell as? TKCollectionViewCell)?.isFirstInSection = { $0.item == 0 }
      (cell as? TKCollectionViewCell)?.isLastInSection = { [unowned collectionView] in
        let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
        return $0.item == numberOfItems - 1
      }
      return cell
    })
    
    super.init()
    
    collectionView.delegate = self
    collectionView.addGestureRecognizer(reorderGesture)
    
    self.dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
      switch TKCollectionSupplementaryItem(rawValue: kind) {
      case .header:
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      case .footer:
        return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
      default:
        return self?.supplementaryViewProvider?(collectionView, kind, indexPath)
      }
    }
    
    self.dataSource.reorderingHandlers.canReorderItem = { [collectionView] item in
      return collectionView.isEditing
    }
    
    self.dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.didReorder?(transaction.difference)
    }
  }
  
  public func collectionView(_ collectionView: UICollectionView, 
                             shouldSelectItemAt indexPath: IndexPath) -> Bool {
    let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
    return isSelectable?(section, indexPath.item) ?? true
  }
  
  public func collectionView(_ collectionView: UICollectionView, 
                             shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
    return isHighlightable?(section, indexPath.item) ?? true
  }
  
  public func collectionView(_ collectionView: UICollectionView, canEditItemAt indexPath: IndexPath) -> Bool {
    let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
    return isEditable?(section, indexPath.item) ?? true
  }
  
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
    didSelect?(section, indexPath.item)
  }
  
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    didScroll?(scrollView)
  }
  
  @objc
  func handleReorderGesture(gesture: UIGestureRecognizer) {
    switch(gesture.state) {
    case .began:
      guard let selectedIndexPath = self.collectionView.indexPathForItem(at: gesture.location(in: self.collectionView)) else {
        break
      }
      collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
    case .changed:
      var location = gesture.location(in: gesture.view!)
      location.x = collectionView.bounds.width/2
      collectionView.updateInteractiveMovementTargetPosition(location)
    case .ended:
      collectionView.endInteractiveMovement()
    default:
      collectionView.cancelInteractiveMovement()
    }
  }
}
