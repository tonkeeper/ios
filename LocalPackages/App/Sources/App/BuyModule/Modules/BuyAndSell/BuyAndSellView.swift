import UIKit
import TKUIKit

final class BuyAndSellView: UIView {
  
  private lazy var dummyView = UIView()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
  }
}

// MARK: - Private

private extension BuyAndSellView {
  func setup() {
    addSubview(dummyView)
    backgroundColor = .Background.page
    
    dummyView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.height.equalTo(500)
    }
  }
}
