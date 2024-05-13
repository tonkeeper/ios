import UIKit
import TKUIKit
import SnapKit

final class SignConfirmationView: UIView, ConfigurableView {
  let scrollView = UIScrollView()
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let containerView = UIView()
  let transactionsView = SignConfirmationTransactionsView()
  let bocView = SignConfirmationBocView()
  let auditButton = UIButton()
  let swipeControl = SwipeControl()
  
  private var bocViewTopConstraint: Constraint?
  private var bocViewBottomConstraint: Constraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let transactionsModel: SignConfirmationTransactionsView.Model
    let bocModel: SignConfirmationBocView.Model
    let auditButtonText: String?
  }
  
  func configure(model: Model) {
    transactionsView.configure(model: model.transactionsModel)
    bocView.configure(model: model.bocModel)
    
    auditButton.setAttributedTitle(
      model.auditButtonText?.withTextStyle(.body2, color: .Text.secondary), for: .normal
    )
    auditButton.setAttributedTitle(model.auditButtonText?.withTextStyle(
      .body2, color: .Text.secondary.withAlphaComponent(0.48)), for: .highlighted
    )
  }
  
  func showBocView() {
    auditButton.removeFromSuperview()
    bocViewTopConstraint?.activate()
    bocViewBottomConstraint?.activate()
    bocView.isHidden = false
    UIView.animate(withDuration: 0.2) {
      self.bocView.alpha = 1
    }
  }
}

private extension SignConfirmationView {
  func setup() {
    scrollView.showsVerticalScrollIndicator = false
    
    addSubview(scrollView)
    scrollView.addSubview(containerView)
    containerView.addSubview(transactionsView)
    containerView.addSubview(bocView)
    containerView.addSubview(auditButton)
    containerView.addSubview(swipeControl)
    
    bocView.isHidden = true
    bocView.alpha = 0
    
    scrollView.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.top.bottom.equalTo(self)
    }
    
    transactionsView.snp.makeConstraints { make in
      make.top.left.right.equalTo(containerView)
    }
    
    bocView.snp.makeConstraints { make in
      bocViewTopConstraint = make.top.equalTo(transactionsView.snp.bottom).offset(16).constraint
      bocViewBottomConstraint = make.bottom.equalTo(swipeControl.snp.top).constraint
      make.left.right.equalTo(containerView)
    }
    
    bocViewTopConstraint?.deactivate()
    bocViewBottomConstraint?.deactivate()
    
    auditButton.snp.makeConstraints { make in
      make.top.equalTo(transactionsView.snp.bottom).offset(20)
      make.bottom.equalTo(swipeControl.snp.top).offset(-12)
      make.left.right.equalTo(containerView)
    }
    
    swipeControl.snp.makeConstraints { make in
      make.left.bottom.right.equalTo(containerView)
    }
    
    containerView.snp.makeConstraints { make in
      make.top.bottom.equalTo(scrollView)
      make.left.equalTo(scrollView).offset(16)
      make.right.equalTo(scrollView).offset(-16)
      make.width.equalTo(scrollView).inset(16).priority(.high)
    }
  }
}
