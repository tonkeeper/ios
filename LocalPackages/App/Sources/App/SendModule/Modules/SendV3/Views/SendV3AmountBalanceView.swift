import UIKit
import TKUIKit
import SnapKit

final class SendV3AmountBalanceView: UIView {
  
  var didTapMax: (() -> Void)?
  
  var convertedValue: String = "" {
    didSet {
      convertedLabel.attributedText = convertedValue.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  let remainingView = SendV3AmountBalanceRemainingView()
  let convertedLabel = UILabel()
  let insufficientLabel = UILabel()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = 8
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 48)
  }

  private func setup() {
    addSubview(stackView)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    stackView.addArrangedSubview(convertedLabel)
    stackView.addArrangedSubview(remainingView)
    stackView.addArrangedSubview(insufficientLabel)
    
    remainingView.didTapMax = { [weak self] in
      self?.didTapMax?()
    }
    
    insufficientLabel.isHidden = true
    insufficientLabel.attributedText = "Insufficient balance".withTextStyle(
      .body2,
      color: .Accent.red,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    convertedLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    remainingView.setContentCompressionResistancePriority(.required, for: .horizontal)
    remainingView.setContentHuggingPriority(.required, for: .horizontal)
    insufficientLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
  }
}

final class SendV3AmountBalanceRemainingView: UIView {
  
  var didTapMax: (() -> Void)?
  
  var remaining: String = "" {
    didSet {
      remainingLabel.attributedText = remaining.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  let remainingLabel = UILabel()
  let maxButton = TKPlainButton()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 48)
  }

  private func setup() {
    maxButton.padding.left = 8
    
    maxButton.configure(
      model: TKPlainButton.Model(
        title: "MAX".withTextStyle(
          .body2,
          color: .Accent.blue,
          alignment: .right,
          lineBreakMode: .byTruncatingTail
        ),
        icon: nil,
        action: { [weak self] in
          self?.didTapMax?()
        }
      )
    )
    setContentHuggingPriority(.required, for: .horizontal)
    maxButton.setContentHuggingPriority(.required, for: .horizontal)
    remainingLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    remainingLabel.isUserInteractionEnabled = false
    
    addSubview(stackView)
    
    stackView.addArrangedSubview(remainingLabel)
    stackView.addArrangedSubview(maxButton)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    maxButton.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
    }
  }
}
