import UIKit
import TKUIKit
import SnapKit

final class SendCommentButton: UIControl, ConfigurableView {
  
  var didTap: (() -> Void)?
  
  override var isHighlighted: Bool {
    didSet {
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  private let highlightView = TKHighlightView()
  private let textLabel = UILabel()
  
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
  
  enum Model {
    case placeholder(String)
    case comment(String)
  }
  
  func configure(model: Model) {
    switch model {
    case .placeholder(let string):
      textLabel.attributedText = string.withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    case .comment(let string):
      textLabel.attributedText = string.withTextStyle(
        .body1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    }
  }
}

private extension SendCommentButton {
  func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    backgroundColor = .Background.content
    
    textLabel.font = TKTextStyle.body1.font
    textLabel.textColor = .Text.secondary
    
    addSubview(highlightView)
    addSubview(textLabel)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTap?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    textLabel.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(20)
      make.left.right.equalTo(self).inset(16)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 64
}
