import UIKit

public final class TKListItemIconView: UIView {
  
  public struct Configuration {
    public struct TextContent {
      public let text: String
      public let font: UIFont
      public let color: UIColor
      
      
      public init(text: String,
                  font: UIFont = .systemFont(ofSize: 24),
                  color: UIColor = .Text.primary) {
        self.text = text
        self.font = font
        self.color = color
      }
    }
    
    public enum Content {
      case image(TKImageView.Model)
      case text(TextContent)
    }
    
    public enum Alignment {
      case top
      case center
    }
    
    public struct Badge {
      public enum Position {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
      }
      
      public let configuration: TKListItemBadgeView.Configuration
      public let position: Position
      
      public init(configuration: TKListItemBadgeView.Configuration,
                  position: Position) {
        self.configuration = configuration
        self.position = position
      }
    }
    
    public let content: Content
    public let alignment: Alignment
    public let cornerRadius: CGFloat
    public let backgroundColor: UIColor
    public let size: CGSize
    public let badge: Badge?
    
    public static var `default`: Configuration {
      Configuration(
        content: .text(
          TextContent(
            text: "T"
          )
        ),
        alignment: .top,
        cornerRadius: 22,
        backgroundColor: .gray,
        size: CGSize(width: 44, height: 44)
      )
    }
    
    public init(content: Content, 
                alignment: Alignment,
                cornerRadius: CGFloat = 0,
                backgroundColor: UIColor = .clear,
                size: CGSize,
                badge: Badge? = nil) {
      self.content = content
      self.alignment = alignment
      self.cornerRadius = cornerRadius
      self.backgroundColor = backgroundColor
      self.size = size
      self.badge = badge
    }
  }
  
  public var configuration = Configuration.default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  public let imageView = TKImageView()
  public let label = UILabel()
  public let badgeView = TKListItemBadgeView()
  private let backgroundView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let backgroundViewFrame: CGRect
    switch configuration.alignment {
    case .top:
      backgroundViewFrame = CGRect(
        origin: CGPoint(x: 0, y: 0),
        size: configuration.size
      )
    case .center:
      backgroundViewFrame = CGRect(
        origin: CGPoint(x: 0, y: bounds.height/2 - configuration.size.height/2),
        size: configuration.size
      )
    }
    backgroundView.frame = backgroundViewFrame
    
    switch configuration.content {
    case .text:
      label.frame = backgroundView.bounds
    case .image:
      let sizeThatFits = imageView.sizeThatFits(.zero)
      let frame = CGRect(origin: CGPoint(x: backgroundView.bounds.width/2 - sizeThatFits.width/2,
                                         y: backgroundView.bounds.height/2 - sizeThatFits.height/2),
                         size: sizeThatFits)
      imageView.frame = frame
    }
    
    if let badge = configuration.badge {
      let size = badgeView.sizeThatFits(.zero)
      let frame: CGRect
      switch badge.position {
      case .bottomLeft:
        frame = CGRect(
          origin: CGPoint(
            x: backgroundViewFrame.minX - 4,
            y: backgroundViewFrame.maxY - size.height + 4
          ),
          size: size
        )
      case .bottomRight:
        frame = CGRect(
          origin: CGPoint(
            x: backgroundViewFrame.maxX - size.width + 4,
            y: backgroundViewFrame.maxY - size.height + 4
          ),
          size: size
        )
      case .topLeft:
        frame = CGRect(
          origin: CGPoint(
            x: backgroundViewFrame.minX - 4,
            y: backgroundViewFrame.minY - 4
          ),
          size: size
        )
      case .topRight:
        frame = CGRect(
          origin: CGPoint(
            x: backgroundViewFrame.maxX - size.width + 4,
            y: backgroundViewFrame.minY - 4
          ),
          size: size
        )
      }
      badgeView.frame = frame
    } else {
      badgeView.frame = .zero
    }
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    configuration.size
  }
  
  public func prepareForReuse() {
    imageView.prepareForReuse()
  }
  
  private func setup() {
    label.textAlignment = .center
    
    addSubview(backgroundView)
    backgroundView.addSubview(imageView)
    backgroundView.addSubview(label)
    addSubview(badgeView)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    switch configuration.content {
    case .image(let imageConfiguration):
      imageView.isHidden = false
      imageView.configure(model: imageConfiguration)
      label.isHidden = true
    case .text(let textContent):
      label.isHidden = false
      label.text = textContent.text
      label.font = textContent.font
      label.textColor = textContent.color
      imageView.isHidden = true
      imageView.configure(model: TKImageView.Model(image: nil))
    }
    
    switch configuration.cornerRadius {
    case 0:
      backgroundView.layer.masksToBounds = false
    default:
      backgroundView.layer.masksToBounds = true
    }
    backgroundView.layer.cornerRadius = configuration.cornerRadius
    
    backgroundView.backgroundColor = configuration.backgroundColor
    
    if let badge = configuration.badge {
      badgeView.isHidden = false
      badgeView.configuration = badge.configuration
    } else {
      badgeView.isHidden = true
      badgeView.configuration = .default
    }
  }
}
