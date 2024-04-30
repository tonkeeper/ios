import UIKit
import SnapKit

public final class TKDetailsTickView: UIControl, ConfigurableView {
  private let contentView = UIView()
  private let textLabel = UILabel()
  private let tickView = TKTickView()
  
  private var height: CGFloat = 0
  
  public override var isHighlighted: Bool {
    didSet {
      textLabel.alpha = isHighlighted ? 0.48 : 1
      tickView.alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    public struct Tick {
      public let isSelected: Bool
      public let closure: ((Bool) -> Void)?
      
      public init(isSelected: Bool, closure: ((Bool) -> Void)?) {
        self.isSelected = isSelected
        self.closure = closure
      }
    }
    
    public let text: String
    public let tick: Tick
    
    public init(text: String, tick: Tick) {
      self.text = text
      self.tick = tick
    }
  }
  
  public func configure(model: Model) {
    tickView.isSelected = model.tick.isSelected
    addAction(UIAction(handler: { [weak self] _ in
      guard let self else { return }
      self.tickView.isSelected.toggle()
      model.tick.closure?(self.tickView.isSelected)
    }), for: .touchUpInside)
    
    textLabel.attributedText = model.text.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    setNeedsLayout()
  }
  
  public override func layoutSubviews() {
    
    let tickViewSize = tickView.intrinsicContentSize
    let textSize = textLabel.sizeThatFits(CGSize(width: bounds.width - tickViewSize.width - .spacing, height: 0))
    
    let contentViewWidth = tickViewSize.width + textSize.width + .spacing
    let contentViewHeight = max(tickViewSize.height, textSize.height)
    contentView.frame = CGRect(x: bounds.width/2 - contentViewWidth/2, y: 0, width: contentViewWidth, height: contentViewHeight)
    
    tickView.frame.origin = .zero
    tickView.frame.size = tickViewSize
    textLabel.frame = CGRect(
      x: tickViewSize.width + .spacing,
      y: contentViewHeight/2 - textSize.height/2,
      width: textSize.width,
      height: textSize.height
    )
    
    height = contentViewHeight
    
    invalidateIntrinsicContentSize()
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: height)
  }
}

private extension TKDetailsTickView {
  func setup() {
    textLabel.numberOfLines = 0
    
    textLabel.isUserInteractionEnabled = false
    tickView.isUserInteractionEnabled = false
    contentView.isUserInteractionEnabled = false

    addSubview(contentView)
    contentView.addSubview(textLabel)
    contentView.addSubview(tickView)
  }
}

private extension CGFloat {
  static let spacing: CGFloat = 8
}
