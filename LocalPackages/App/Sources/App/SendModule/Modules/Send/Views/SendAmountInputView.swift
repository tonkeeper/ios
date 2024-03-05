import UIKit
import TKUIKit
import SnapKit

final class SendAmountInputView: UIControl, ConfigurableView {
  
  var didTap: (() -> Void)?
  
  override var isHighlighted: Bool {
    didSet {
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  private let highlightView = TKHighlightView()
  private let amountLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  struct Model {
    let amount: NSAttributedString
    
    init(amount: String) {
      self.amount = amount.withTextStyle(
        .num2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  func configure(model: Model) {
    amountLabel.attributedText = model.amount
  }
}

private extension SendAmountInputView {
  func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    backgroundColor = .Background.content
    
    amountLabel.adjustsFontSizeToFitWidth = true
    amountLabel.minimumScaleFactor = 0.3
    
    addSubview(highlightView)
    addSubview(amountLabel)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTap?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    amountLabel.snp.makeConstraints { make in
      make.centerY.equalTo(self)
      make.left.right.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 144
}
