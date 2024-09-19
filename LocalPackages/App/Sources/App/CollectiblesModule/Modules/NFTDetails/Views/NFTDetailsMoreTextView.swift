import UIKit
import TKUIKit
import SnapKit

final class NFTDetailsMoreTextView: TKView, ConfigurableView {
  
  var didExpand: (() -> Void)?
  
  var numberOfLinesCollapsed = 2
  private var isExpanded = false {
    didSet {
      invalidateIntrinsicContentSize()
      moreButton.isHidden = isExpanded
      didExpand?()
    }
  }
  
  let label = UILabel()
  private let moreButton = MoreButton()
  
  private var cachedWidth: CGFloat?
  
  override func setup() {
    super.setup()
    layer.masksToBounds = true
    
    label.numberOfLines = 0
    
    addSubview(label)
    addSubview(moreButton)
    
    moreButton.addAction(UIAction(handler: { [weak self] _ in
      self?.isExpanded = true
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    label.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    moreButton.snp.makeConstraints { make in
      make.right.bottom.equalTo(self)
    }
  }
  
  struct Model {
    let text: NSAttributedString?
    let readMoreText: NSAttributedString
    
    init(text: String?, readMoreText: String) {
      self.text = text?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
      self.readMoreText = readMoreText.withTextStyle(
        .body2,
        color: .Text.accent,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width != cachedWidth {
      cachedWidth = bounds.width
      invalidateIntrinsicContentSize()
    }
  }
  
  func configure(model: Model) {
    label.attributedText = model.text
    moreButton.label.attributedText = model.readMoreText
    cachedWidth = nil
    
//    let textViewSizeThatFits = label.sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
//    let maximumHeight = TKTextStyle.body2.lineHeight * CGFloat(numberOfLinesCollapsed)
//    moreButton.isHidden = !(isExpanded || textViewSizeThatFits.height > maximumHeight)
    
    setNeedsLayout()
  }
  
  override var intrinsicContentSize: CGSize {
    let textViewSizeThatFits = label.sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
    guard !isExpanded else {
      return CGSize(width: UIView.noIntrinsicMetric, height: textViewSizeThatFits.height)
    }
    
    let maximumHeight = TKTextStyle.body2.lineHeight * CGFloat(numberOfLinesCollapsed)
    return CGSize(width: UIView.noIntrinsicMetric, height: min(maximumHeight, textViewSizeThatFits.height))
  }
}

private final class MoreButton: UIControl {
  
  override var isHighlighted: Bool {
    didSet {
      label.alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  let label = UILabel()
  let backgroundView = UIView()
  let gradientLayer = CAGradientLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    backgroundColor = .clear
    
    label.isUserInteractionEnabled = false
    backgroundView.isUserInteractionEnabled = false
    
    gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
    gradientLayer.locations = [0, 0.35, 1]
    gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
    gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    
    backgroundView.backgroundColor = .Background.content
    backgroundView.layer.mask = gradientLayer
    
    addSubview(backgroundView)
    addSubview(label)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    let labelIntrinsicContentSize = label.intrinsicContentSize
    return CGSize(width: labelIntrinsicContentSize.width + 24, height: labelIntrinsicContentSize.height + 20)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    backgroundView.frame = CGRect(x: 0, y: bounds.height - 20, width: bounds.width, height: 20)
    gradientLayer.frame = backgroundView.bounds
    
    label.sizeToFit()
    label.frame.origin = CGPoint(x: bounds.width - label.bounds.width, y: bounds.height - label.bounds.height)
  }
}
