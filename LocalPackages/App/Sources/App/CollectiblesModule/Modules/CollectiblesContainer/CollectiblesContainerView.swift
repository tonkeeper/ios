import UIKit
import TKUIKit

final class CollectiblesContainerView: UIView {
  private let containerView = UIView()
  
  private var contentView: UIView?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setContentView(_ contentView: UIView?) {
    self.contentView?.removeFromSuperview()
    self.contentView = contentView
    
    guard let contentView else { return }
    containerView.addSubview(contentView)
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(containerView)
    }
  }
  
  private func setup() {
    backgroundColor = .Background.page
    
    addSubview(containerView)
    
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
