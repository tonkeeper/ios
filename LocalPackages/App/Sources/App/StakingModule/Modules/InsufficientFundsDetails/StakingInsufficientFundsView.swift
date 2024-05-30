import UIKit
import TKUIKit
import SnapKit
import TKCore


final class StakingInsufficientFundsView: UIView {
  
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
    view.fill(in: modalContentContainer)
  }
}

// MARK: - Private methods

private extension StakingInsufficientFundsView {
  func setup() {
    modalContentContainer.layout(in: self) {
      $0.top.equalToSuperview()
      $0.leading.equalToSuperview()
      $0.trailing.equalToSuperview().priority(.high)
      $0.bottom.equalToSuperview().priority(.high)
    }
  }
}
