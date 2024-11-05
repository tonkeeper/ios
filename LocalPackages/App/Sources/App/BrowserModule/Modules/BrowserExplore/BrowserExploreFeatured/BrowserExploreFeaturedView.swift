import UIKit
import TKUIKit
import SnapKit
import KeeperCore
import TKCore

final class BrowserExploreFeaturedView: UIView {
  
  var didSelectApp: ((Int) -> Void)?

  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  var dapps = [Dapp]() {
    didSet {
      guard dapps != oldValue else { return }
      let models = dapps.map { dapp in
       mapDapp(dapp)
      }
      
      let dataSource = (0..<Int.numberOfAdditionalItems).reduce(into: [BrowserExploreFeaturedCell.Model]()) { partialResult, _  in
        partialResult = partialResult + models
      }
      
      self.dataSource = dataSource
    }
  }
  
  private var dataSource = [BrowserExploreFeaturedCell.Model]() {
    didSet {
      collectionView.alpha = 0
      collectionView.reloadData()
      collectionView.layoutIfNeeded()
      guard !dataSource.isEmpty else { return }
      DispatchQueue.main.async {
        let indexOfLeftSignificantCell = Int.numberOfAdditionalItems/2 * self.dapps.count
        self.collectionView.scrollToItem(at: IndexPath(item: indexOfLeftSignificantCell, section: 0), at: .centeredHorizontally, animated: false)
        UIView.animate(withDuration: 0.2) {
          self.collectionView.alpha = 1.0
        }
        self.startSlideShowTask()
      }
    }
  }

  private lazy var collectionView = CollectionView(frame: .zero, collectionViewLayout: createLayout())
  
  private var indexOfCellBeforeDragging = 0
  private var slideshowTask: Task<Void, Never>?
  
  func createLayout() -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .horizontal
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { _, environment -> NSCollectionLayoutSection? in
      let width = environment.container.effectiveContentSize.width
      
      let itemSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(environment.container.effectiveContentSize.height)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemSize)
      item.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)
      
      let groupSize = NSCollectionLayoutSize(
        widthDimension: .absolute(self.calculateItemSize(width: width)),
        heightDimension: .absolute(environment.container.effectiveContentSize.height)
      )
      
      let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
      
      let section = NSCollectionLayoutSection(group: group)
      return section
      
    }, configuration: configuration)
    return layout
  }
  
  func calculateItemSize(width: CGFloat) -> CGFloat {
    let itemInset: CGFloat = 8
    return width - itemInset * 4
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.backgroundColor = .clear
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.decelerationRate = .fast
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(
      BrowserExploreFeaturedCell.self,
      forCellWithReuseIdentifier: BrowserExploreFeaturedCell.reuseIdentifier
    )
    
    addSubview(collectionView)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    collectionView.frame = bounds
  }
  
  func startSlideShow() {
    startSlideShowTask()
  }
  
  func stopSlideShow() {
    slideshowTask?.cancel()
    slideshowTask = nil
  }
  
  override func didMoveToSuperview() {
    guard superview != nil else {
      stopSlideShow()
      return
    }
    startSlideShow()
  }
}

private extension BrowserExploreFeaturedView {

  func indexOfMostVisibleCell(offset: Int = 0) -> Int {
      let itemWidth = calculateItemSize(width: collectionView.bounds.width)
      let proportionalOffset = collectionView.contentOffset.x / itemWidth
      let index = Int(round(proportionalOffset)) + offset
      let numberOfItems = collectionView.numberOfItems(inSection: 0)
      let safeIndex = max(0, min(numberOfItems - 1, index))
      return safeIndex
  }

  var indexOfLeftSignificantCell: Int { Int.numberOfAdditionalItems/2 * self.dapps.count }
  var indexOfRightSignificantCell: Int { indexOfLeftSignificantCell + self.dapps.count - 1 }
  
  func startSlideShowTask() {
    slideshowTask?.cancel()
    slideshowTask = Task {
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        resetCarouselIfNeeded()
        self.collectionView.isScrollEnabled = false
        UIView.animate(withDuration: 0.5) {
          self.collectionView.scrollToItem(
            at: IndexPath(item: self.indexOfMostVisibleCell(offset: 1), section: 0),
            at: .centeredHorizontally,
            animated: true
          )
        } completion: { _ in
          self.collectionView.isScrollEnabled = true
          self.startSlideShowTask()
        }
      }
    }
  }
}

extension BrowserExploreFeaturedView: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    dataSource.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: BrowserExploreFeaturedCell.reuseIdentifier,
      for: indexPath
    )
    
    (cell as? BrowserExploreFeaturedCell)?.configure(model: dataSource[indexPath.item])
    
    return cell
  }
}

extension BrowserExploreFeaturedView: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    didSelectApp?(indexPath.item - ((indexPath.item / dapps.count) * dapps.count))
  }
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    indexOfCellBeforeDragging = indexOfMostVisibleCell()
    slideshowTask?.cancel()
  }
  
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    targetContentOffset.pointee = scrollView.contentOffset
    
    let indexOfMostVisibleCell = self.indexOfMostVisibleCell()
    let numberOfItems = collectionView.numberOfItems(inSection: 0)
    let swipeVelocityThreshold: CGFloat = 0.5
    let hasEnoughVelocityToSlideToTheNextCell = indexOfCellBeforeDragging + 1 < numberOfItems && velocity.x > swipeVelocityThreshold
    let hasEnoughVelocityToSlideToThePreviousCell = indexOfCellBeforeDragging - 1 >= 0 && velocity.x < -swipeVelocityThreshold
    let majorCellIsTheCellBeforeDragging = indexOfMostVisibleCell == indexOfCellBeforeDragging
    let didUseSwipeToSkipCell = majorCellIsTheCellBeforeDragging && (hasEnoughVelocityToSlideToTheNextCell || hasEnoughVelocityToSlideToThePreviousCell)
    
    if didUseSwipeToSkipCell {
      
      let snapToIndex = indexOfCellBeforeDragging + (hasEnoughVelocityToSlideToTheNextCell ? 1 : -1)
      let toValue = calculateItemSize(width: collectionView.bounds.width) * CGFloat(snapToIndex)
      
      UIView.animate(withDuration: 0.5,
                     delay: 0,
                     usingSpringWithDamping: 1,
                     initialSpringVelocity: velocity.x,
                     options: .allowUserInteraction, animations: {
        scrollView.contentOffset = CGPoint(x: toValue - 16, y: 0)
        scrollView.layoutIfNeeded()
      }, completion: nil)
      
    } else {
      let indexPath = IndexPath(row: indexOfMostVisibleCell, section: 0)
      collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    resetCarouselIfNeeded()
    startSlideShowTask()
  }
  
  func resetCarouselIfNeeded() {
    let indexOfMostVisibleCell = self.indexOfMostVisibleCell()
    let indexOfLeftSignificantCell = Int.numberOfAdditionalItems/2 * self.dapps.count
    let indexOfRightSignificantCell = indexOfLeftSignificantCell + self.dapps.count - 1
    
    if indexOfMostVisibleCell == indexOfLeftSignificantCell - 1 {
      collectionView.scrollToItem(at: IndexPath(item: indexOfRightSignificantCell, section: 0),
                                  at: .centeredHorizontally, animated: false)
    }
    
    if indexOfMostVisibleCell == indexOfRightSignificantCell + 1 {
      collectionView.scrollToItem(at: IndexPath(item: indexOfLeftSignificantCell, section: 0),
                                       at: .centeredHorizontally, animated: false)
    }
  }
  
  func mapDapp(_ dapp: Dapp) -> BrowserExploreFeaturedCell.Model {
    
    let textColor: UIColor
    if let itemTextColor = dapp.textColor {
      textColor = UIColor(hex: itemTextColor)
    } else {
      textColor = .Constant.white
    }
    
    let listModel = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: .asyncImage(dapp.icon, TKCore.ImageDownloadTask(
              closure: {
                [imageLoader] imageView,
                size,
                cornerRadius in
                return imageLoader.loadImage(
                  url: dapp.icon,
                  imageView: imageView,
                  size: size,
                  cornerRadius: cornerRadius
                )
              }
            )),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 12
          )
        ),
        alignment: .center
      ),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: dapp.name.withTextStyle(.label2, color: textColor),
          tagViewModel: nil,
          subtitle: nil,
          description: dapp.description?.withTextStyle(
            .body3Alternate,
            color: textColor.withAlphaComponent(0.76),
            lineBreakMode: .byTruncatingTail
          ),
          descriptionNumberOfLines: 2
        ),
        rightItemConfiguration: nil,
        isVerticalCenter: true
      ),
      accessoryConfiguration: .none
    )
    
    let posterImageTask = TKCore.ImageDownloadTask { imageView, size, cornerRadius in
      return self.imageLoader.loadImage(
        url: dapp.poster,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }
    
    return BrowserExploreFeaturedCell.Model(
      posterImageTask: posterImageTask,
      listModel: listModel
    )
  }
}

private extension Int {
  static let numberOfAdditionalItems = 5
}

private class CollectionView : UICollectionView {
  private var _safeAreaInsets:UIEdgeInsets?
  override var safeAreaInsets:UIEdgeInsets {
    get { _safeAreaInsets ?? super.safeAreaInsets }
    set { _safeAreaInsets = newValue }
  }
}
