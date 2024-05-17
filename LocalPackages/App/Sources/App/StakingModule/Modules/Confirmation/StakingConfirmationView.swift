import UIKit
import TKUIKit
import SnapKit
import TKCore


final class StakingConfirmationView: UIView {
  
  private let modalContentContainer = UIView()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedContent(_ view: UIView) {
    modalContentContainer.addSubview(view)
    
    view.snp.makeConstraints { make in
      make.edges.equalTo(modalContentContainer)
    }
  }
}

// MARK: - Private methods

private extension StakingConfirmationView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(modalContentContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    modalContentContainer.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.bottom.right.equalTo(self).priority(.high)
    }
  }
}
