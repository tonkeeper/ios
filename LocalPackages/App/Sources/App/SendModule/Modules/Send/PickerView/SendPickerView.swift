import UIKit
import TKUIKit
import SnapKit

final class SendPickerView: UIView {
  typealias Item = SendPickerCell.Model
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  
  enum Section {
    case items
  }
  
  var shouldHighlightItem: ((IndexPath) -> Bool)?
  var didScrollToItem: ((Int) -> Void)?
  var didTapItem: ((IndexPath) -> Void)?
  var didTapAmount: ((IndexPath) -> Void)?
  
  var items: [Item] {
    get {
      dataSource.snapshot().itemIdentifiers(inSection: .items)
    }
    set {
      var snapshot = dataSource.snapshot()
      snapshot.deleteAllItems()
      snapshot.appendSections([.items])
      snapshot.appendItems(newValue, toSection: .items)
      snapshot.reloadItems(newValue)
      UIView.performWithoutAnimation {
        dataSource.apply(snapshot)
      }
      
      pageControl.numberOfPages = items.count
    }
  }
  
  // Subviews
  
  private let collectionView = UICollectionView(
    frame: .zero,
    collectionViewLayout: UICollectionViewLayout()
  )
  
  private let pageControl = TKPageControl()
  
  // Collection
  
  private lazy var dataSource = createDataSource()
  
  // Constraints
  
  private var collectionViewHeightConstraint: Constraint?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    invalidateIntrinsicContentSize()
  }
  
  func selectItem(at index: Int) {
    DispatchQueue.main.async {
      self.collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .left, animated: false)
      self.pageControl.currentPage = index
    }
  }
}

private extension SendPickerView {
  func setup() {
    collectionView.isPagingEnabled = true
    collectionView.backgroundColor = .Background.page
    collectionView.delegate = self
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.register(
      SendPickerCell.self,
      forCellWithReuseIdentifier: SendPickerCell.reuseIdentifier
    )
    
    pageControl.padding = .pageControlPadding
    
    addSubview(collectionView)
    addSubview(pageControl)
    
    setupConstraints()
    
    setupCollectionViewLayout()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
      self.collectionViewHeightConstraint = make.height.equalTo(CGFloat.minimumCollectionHeight).constraint
    }
    pageControl.snp.makeConstraints { make in
      make.top.equalTo(collectionView.snp.bottom)
      make.left.right.equalTo(self)
      make.bottom.equalTo(self).priority(.high)
    }
  }
  
  func createDataSource() -> DataSource {
    DataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: SendPickerCell.reuseIdentifier,
        for: indexPath
      ) as? SendPickerCell
      cell?.configure(model: itemIdentifier)
      cell?.didTapAmount = { [weak self] in
        self?.didTapAmount?(indexPath)
      }
      return cell
    }
  }
  
  func setupCollectionViewLayout() {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .horizontal
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, environment in
      let item: NSCollectionLayoutItem
      if #available(iOS 17.0, *) {
        item = NSCollectionLayoutItem(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
          )
        )
      } else {
        item = NSCollectionLayoutItem(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
          )
        )
      }
      
      let group = NSCollectionLayoutGroup.vertical(
        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(76)),
        subitems: [item]
      )
      group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
      let sectionLayout = NSCollectionLayoutSection(group: group)
      
      return sectionLayout
    }, configuration: configuration)
    
    collectionView.setCollectionViewLayout(layout, animated: false)
  }
}

extension SendPickerView: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    didTapItem?(indexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    shouldHighlightItem?(indexPath) ?? false
  }
  
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    let itemWidth = scrollView.frame.width
    let contentOffset = targetContentOffset.pointee.x
    
    let targetItem = lround(Double(contentOffset/itemWidth))
    let targetIndex = targetItem % items.count
    pageControl.currentPage = targetIndex
    didScrollToItem?(targetIndex)
  }
}

private extension CGFloat {
  static let minimumCollectionHeight: CGFloat = 76
}

private extension UIEdgeInsets {
  static var pageControlPadding = UIEdgeInsets(top: 12, left: 0, bottom: 10, right: 0)
}
