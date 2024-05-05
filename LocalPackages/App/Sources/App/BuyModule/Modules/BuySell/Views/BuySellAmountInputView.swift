import UIKit
import TKUIKit

final class BuySellAmountInputView: UIView {
  
  var didUpdateText: ((String?) -> Void)?
  
  // MARK: - Views
    
  let amountTokenTitleLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.h2.font
    label.textAlignment = .left
    return label
  }()
  
  lazy var amountTextField: BuySellAmountTextField = {
    let textField = BuySellAmountTextField()
    textField.textAlignment = .right
    return textField
  }()
  
  lazy var convertedAmountLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    return label
  }()
  
  lazy var convertedCurrencyLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    return label
  }()
  
  lazy var minAmountLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.font = TKTextStyle.label2.font
    return label
  }()
  
  private let convertedContainer: UIView = {
    let view = UIView()
    view.layer.borderWidth = 1.5
    view.layer.borderColor = UIColor.Button.tertiaryBackground.cgColor
    view.layer.cornerRadius = .convertedContainerCornerRadius
    view.layer.cornerCurve = .continuous
    return view
  }()
    
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Setup
  
  private func setup() {
    addSubview(amountTextField)
    addSubview(amountTokenTitleLabel)
    addSubview(minAmountLabel)
    addSubview(convertedContainer)
    addSubview(convertedAmountLabel)
    addSubview(convertedCurrencyLabel)
    
    setupConstraints()
    
    amountTextField.didUpdateText = { [weak self] text in
      self?.didUpdateText?(text)
    }
  }
  
  private func setupConstraints() {
    let amountTextViewLayoutGuide = UILayoutGuide()
    addLayoutGuide(amountTextViewLayoutGuide)
    
    amountTextViewLayoutGuide.snp.makeConstraints { make in
      make.top.equalTo(self).offset(CGFloat.amountTextViewTopPadding)
      make.left.equalTo(amountTextField)
      make.right.equalTo(amountTokenTitleLabel)
      make.height.equalTo(CGFloat.amountTextViewHeight)
      make.centerX.equalTo(self)
    }
    
    amountTextField.snp.makeConstraints { make in
      make.centerY.equalTo(amountTextViewLayoutGuide)
    }
    
    amountTokenTitleLabel.snp.makeConstraints { make in
      make.left.equalTo(amountTextField.snp.right).offset(12)
      make.lastBaseline.equalTo(amountTextField)
    }
    
    convertedContainer.snp.makeConstraints { make in
      make.top.equalTo(amountTextViewLayoutGuide.snp.bottom)
      make.left.equalTo(convertedAmountLabel).offset(-CGFloat.contentVerticalPadding)
      make.right.equalTo(convertedCurrencyLabel).offset(CGFloat.contentVerticalPadding)
      make.height.equalTo(CGFloat.convertedContainerHeight)
      make.centerX.equalTo(self)
    }
    
    convertedAmountLabel.snp.makeConstraints { make in
      make.centerY.equalTo(convertedContainer)
    }
    
    convertedCurrencyLabel.snp.makeConstraints { make in
      make.left.equalTo(convertedAmountLabel.snp.right).offset(4)
      make.lastBaseline.equalTo(convertedAmountLabel)
    }
    
    minAmountLabel.snp.makeConstraints { make in
      make.top.equalTo(convertedContainer.snp.bottom).offset(12)
      make.leading.equalTo(self).offset(CGFloat.contentVerticalPadding)
      make.trailing.equalTo(self).inset(CGFloat.contentVerticalPadding)
      make.height.equalTo(CGFloat.minAmountLabelHeight)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 178
  static let contentVerticalPadding: CGFloat = 16
  static let amountTextViewTopPadding: CGFloat = 24
  static let amountTextViewHeight: CGFloat = 70
  static let convertedContainerHeight: CGFloat = 40
  static let convertedContainerCornerRadius: CGFloat = .convertedContainerHeight / 2
  static let minAmountLabelHeight: CGFloat = 20
}
