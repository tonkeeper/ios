import UIKit

public final class TKUIListItemEmojiIconView: UIView, TKConfigurableView, ReusableView {
  
  let emojiLabel = UILabel()
  private var size: CGFloat = .zero
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    emojiLabel.sizeToFit()
    emojiLabel.center = CGPoint(x: bounds.width/2,
                                y: bounds.height/2)
    layer.cornerRadius = size/2
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: self.size, height: self.size)
  }
  
  public struct Configuration: Hashable {
    public let emoji: String
    public let backgroundColor: UIColor
    public let size: CGFloat
    
    public init(emoji: String,
                backgroundColor: UIColor,
                size: CGFloat) {
      self.emoji = emoji
      self.backgroundColor = backgroundColor
      self.size = size
    }
  }
  
  public func configure(configuration: Configuration) {
    emojiLabel.text = configuration.emoji
    size = configuration.size
    backgroundColor = configuration.backgroundColor
    setNeedsLayout()
  }
}

private extension TKUIListItemEmojiIconView {
  func setup() {
    layer.masksToBounds = true
    
    emojiLabel.font = .systemFont(ofSize: 24)
    emojiLabel.textAlignment = .center
    
    addSubview(emojiLabel)
  }
}
