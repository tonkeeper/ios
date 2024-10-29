import UIKit
import TKUIKit

final class StakingInputView: TKView {
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      continueButtonContainer.snp.remakeConstraints { make in
        make.left.right.equalTo(self)
        make.bottom.equalTo(self).inset(keyboardHeight)
      }
      continueButtonContainer.setNeedsLayout()
      continueButtonContainer.layoutIfNeeded()
      
      scrollView.contentInset.bottom = keyboardHeight == 0 ? keyboardHeight : keyboardHeight
      scrollView.contentInset.bottom += continueButtonContainer.frame.height
    }
  }
  
  let navigationBar = TKUINavigationBar()
  let titleView = TKUINavigationBarTitleView()
  let scrollView = TKUIScrollView()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .init(
      top: 0,
      leading: .contentPadding,
      bottom: .contentPadding,
      trailing: .contentPadding
    )
    
    return stackView
  }()
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  let continueButtonContainer = TKPaddingContainerView()
  let balanceView = StakingInputBalanceView()
  let detailsViewContainer = TKPaddingContainerView()
  private let detailsContainer = UIView()
  private let amountInputContainer = UIView()
  
  func setAmountInputView(_ view: UIView) {
    amountInputContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(amountInputContainer)
    }
  }
  
  func setDetailsView(_ view: UIView) {
    detailsContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(detailsContainer)
    }
  }
  
  override func setup() {
    super.setup()
    backgroundColor = .Background.page
    
    navigationBar.centerView = titleView
    
    detailsViewContainer.isHidden = true
    detailsViewContainer.padding.top = 16
    detailsViewContainer.setViews([detailsContainer])
    
    continueButtonContainer.setViews([continueButton])
    continueButtonContainer.padding.top = 16
    continueButtonContainer.padding.left = 16
    continueButtonContainer.padding.right = 16
    
    addSubview(scrollView)
    addSubview(continueButtonContainer)
    addSubview(navigationBar)
    scrollView.addSubview(contentStackView)
    contentStackView.addArrangedSubview(amountInputContainer)
    contentStackView.setCustomSpacing(16, after: amountInputContainer)
    contentStackView.addArrangedSubview(balanceView)
    contentStackView.setCustomSpacing(16, after: balanceView)
    contentStackView.addArrangedSubview(detailsViewContainer)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self).priority(.high)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.top.equalTo(self.scrollView)
      make.left.right.bottom.equalTo(self.scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
    
    amountInputContainer.snp.makeConstraints { make in
      make.height.greaterThanOrEqualTo(CGFloat.amountInputHeight)
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.bottom.equalTo(self).inset(keyboardHeight)
    }
  }
}

private extension CGFloat {
  static let contentPadding: CGFloat = 16
  static let amountInputHeight: CGFloat = 188
}
