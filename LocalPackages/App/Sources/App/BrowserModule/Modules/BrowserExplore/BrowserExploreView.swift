import UIKit
import TKUIKit

final class BrowserExploreView: UIView {
  
  enum State {
    case data
    case empty(BrowserExploreEmptyView.Model)
  }
  
  var state: State = .data {
    didSet {
      setupState()
    }
  }
  
  var topInset: CGFloat = 0 {
    didSet {
      topLayoutGuide.snp.remakeConstraints { make in
        make.left.right.equalTo(self)
        make.top.equalTo(self)
        make.height.equalTo(topInset)
      }
    }
  }
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  let emptyView = BrowserExploreEmptyView()
  
  let topLayoutGuide = UILayoutGuide()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension BrowserExploreView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    collectionView.contentInsetAdjustmentBehavior = .never
    
    addSubview(collectionView)
    addSubview(emptyView)
    
    addLayoutGuide(topLayoutGuide)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    emptyView.snp.makeConstraints { make in
      make.top.equalTo(topLayoutGuide.snp.bottom)
      make.left.right.equalTo(self).inset(16)
    }
    
    topLayoutGuide.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.top.equalTo(self)
      make.height.equalTo(topInset)
    }
  }
  
  func setupState() {
    switch state {
    case .data:
      emptyView.isHidden = true
      collectionView.isHidden = false
    case .empty(let model):
      emptyView.configure(model: model)
      emptyView.isHidden = false
      collectionView.isHidden = true
    }
  }
}
