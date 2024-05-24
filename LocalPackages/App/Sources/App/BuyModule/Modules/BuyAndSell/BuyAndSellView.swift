import UIKit
import TKUIKit
import SnapKit

final class BuyAndSellView: UIView {
  
  struct Model {
    struct Amount {
      let placeholder: String
      let text: String?
    }
    
    public let isContinueButtonEnabled: Bool
    public let minAmountDisclaimer: String
    public let amount: Amount
    public let convertedAmount: String
  }
  
  lazy var amountView = BuyAndSellAmountView()
  
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()
  
  private var continueButtonContainerSafeAreaBottomConstraint: Constraint?
  private var continueButtonContainerBottomConstraint: Constraint?
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      if keyboardHeight.isZero {
        continueButtonContainerBottomConstraint?.isActive = false
        continueButtonContainerSafeAreaBottomConstraint?.isActive = true
      } else {
        continueButtonContainerSafeAreaBottomConstraint?.isActive = false
        continueButtonContainerBottomConstraint?.update(inset: keyboardHeight)
        continueButtonContainerBottomConstraint?.isActive = true
      }
    }
  }
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension BuyAndSellView {
  func setup() {
    addSubview(amountView)
    addSubview(continueButtonContainer)
    
    continueButtonContainer.setViews([continueButton])
    
    amountView.layer.cornerRadius = 24
    
    backgroundColor = .Background.page
    
    amountView.snp.makeConstraints { make in
      make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
      make.leading.equalTo(self).offset(16)
      make.trailing.equalTo(self).offset(-16)
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      make.leading.equalToSuperview()
      make.trailing.equalToSuperview()
      self.continueButtonContainerBottomConstraint = make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom).constraint
      self.continueButtonContainerBottomConstraint = make.bottom.equalTo(self.snp.bottom).constraint
    }
  }
}

private extension UIEdgeInsets {
  
  static let continueButtonPadding = UIEdgeInsets(
    top: 16,
    left: 16,
    bottom: 16,
    right: 16
  )
}
