import UIKit
import TKUIKit

final class SignRawConfirmationView: UIView {
  private let contentContainer = UIView()
  
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
    contentContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(contentContainer)
    }
  }
}

// MARK: - Private

private extension SignRawConfirmationView {
  func setup() {
    addSubview(contentContainer)
    
    contentContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
