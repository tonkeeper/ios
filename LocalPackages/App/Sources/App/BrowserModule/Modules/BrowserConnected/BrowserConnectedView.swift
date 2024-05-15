import UIKit
import TKUIKit

final class BrowserConnectedView: UIView {
  
  enum State {
    case data
    case empty(TKEmptyStateView.Model)
  }
  
  var state: State = .data {
    didSet {
      setupState()
    }
  }
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  let emptyView = TKEmptyStateView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension BrowserConnectedView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    collectionView.contentInsetAdjustmentBehavior = .never
    
    addSubview(collectionView)
    addSubview(emptyView)
    
    setupState()
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    emptyView.snp.makeConstraints { make in
      make.edges.equalTo(self)
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
