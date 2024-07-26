import UIKit

public final class TKCommentView: UIControl, ConfigurableView, ReusableView {
  
  let textBackground: UIView = {
    let view = UIView()
    view.backgroundColor = .Bubble.background
    view.layer.cornerRadius = .cornerRadius
    view.isUserInteractionEnabled = false
    return view
  }()
  
  let textLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  private let highlightView = TKHighlightView()
  
  public override var isHighlighted: Bool {
    didSet {
      guard tapClosure != nil else { return }
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  private var tapClosure: (() -> Void)?
  
  public struct Model {
    let comment: NSAttributedString
    let tapClosure: (() -> Void)?
    
    public init(comment: NSAttributedString, tapClosure: (() -> Void)? = nil) {
      self.comment = comment
      self.tapClosure = tapClosure
    }
    
    public init(comment: String, tapClosure: (() -> Void)? = nil) {
      self.comment = comment.withTextStyle(.body2, color: .Bubble.foreground)
      self.tapClosure = tapClosure
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let textAvailableWidth = bounds.width - .textHorizontalSpacing * 2
    let textSize = textLabel.tkSizeThatFits(textAvailableWidth)
    
    textBackground.frame = .init(x: 0,
                                 y: .topSpace,
                                 width: textSize.width + .textHorizontalSpacing * 2,
                                 height: textSize.height + .textTopSpacing + .textBottomSpacing)
    textLabel.frame = .init(x: .textHorizontalSpacing,
                            y: .textTopSpacing,
                            width: textBackground.bounds.width - .textHorizontalSpacing * 2,
                            height: textBackground.bounds.height - .textBottomSpacing - .textTopSpacing)
    
    highlightView.frame = textBackground.bounds
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    guard let text = textLabel.text, !text.isEmpty else { return .zero }
    let textWidth = size.width - .textHorizontalSpacing * 2
    let textSize = textLabel.tkSizeThatFits(textWidth)
    return .init(width: textSize.width + .textHorizontalSpacing * 2,
                 height: textSize.height + .textTopSpacing + .textBottomSpacing + .topSpace)
  }
  
  public func configure(model: Model) {
    textLabel.attributedText = model.comment
    tapClosure = model.tapClosure
    isUserInteractionEnabled = tapClosure != nil
    setNeedsLayout()
  }
  
  public func prepareForReuse() {
    textLabel.attributedText = nil
  }
}

private extension TKCommentView {
  func setup() {
    addSubview(textBackground)
    textBackground.addSubview(highlightView)
    textBackground.addSubview(textLabel)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapClosure?()
    }), for: .touchUpInside)
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 12
  static let textTopSpacing: CGFloat = 7.5
  static let textBottomSpacing: CGFloat = 8.5
  static let textHorizontalSpacing: CGFloat = 12
  static let topSpace: CGFloat = 8
}
