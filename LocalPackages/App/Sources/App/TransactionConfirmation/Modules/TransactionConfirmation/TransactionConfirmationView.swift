import UIKit
import TKUIKit

final class TransactionConfirmationView: UIView {
  let navigationBar = TKUINavigationBar()
  private let modalContentContainer = UIView()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Content
  
  func embedContent(_ view: UIView) {
    modalContentContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(modalContentContainer)
    }
  }
}

// MARK: - Private

private extension TransactionConfirmationView {
  func setup() {
    addSubview(modalContentContainer)
    addSubview(navigationBar)
        
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    modalContentContainer.snp.makeConstraints { make in
      make.top.equalTo(navigationBar.snp.bottom)
      make.left.bottom.right.equalTo(self)
    }
  }
}
