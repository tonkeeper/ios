import UIKit
import TKUIKit

final class StakeOptionsView: UIView, ConfigurableView {
  
  let titleView = ModalTitleView()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: ModalTitleView.Model
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
  }
}

// MARK: - Setup

private extension StakeOptionsView {
  func setup() {
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
