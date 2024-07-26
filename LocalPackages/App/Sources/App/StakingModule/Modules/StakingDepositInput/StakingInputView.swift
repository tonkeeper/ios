import UIKit
import TKUIKit

final class StakingInputView: TKView {
  let scrollView = TKUIScrollView()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .init(
      top: .contentPadding,
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
    
    detailsViewContainer.isHidden = true
    detailsViewContainer.padding.top = 16
    detailsViewContainer.setViews([detailsContainer])
    
    continueButtonContainer.setViews([continueButton])
    continueButtonContainer.padding.top = 16
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    contentStackView.addArrangedSubview(amountInputContainer)
    contentStackView.setCustomSpacing(16, after: amountInputContainer)
    contentStackView.addArrangedSubview(balanceView)
    contentStackView.setCustomSpacing(16, after: balanceView)
    contentStackView.addArrangedSubview(detailsViewContainer)
    contentStackView.addArrangedSubview(continueButtonContainer)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
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
  }
}

private extension CGFloat {
  static let contentPadding: CGFloat = 16
  static let amountInputHeight: CGFloat = 188
}
