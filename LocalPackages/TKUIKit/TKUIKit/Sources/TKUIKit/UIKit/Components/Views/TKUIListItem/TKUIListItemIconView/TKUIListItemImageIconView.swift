import UIKit

public final class TKUIListItemImageIconView: UIView, TKConfigurableView, ReusableView {
  
  private let imageView = UIImageView()
  
  private var size: CGSize = .zero
  private var imageSize: CGSize = .zero
  private var cornerRadius: CGFloat = 0
  private var imageDownloadTask: ImageDownloadTask?
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.frame.size = imageSize
    imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    self.size
  }
  
  public func prepareForReuse() {
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    imageView.image = nil
  }
  
  public struct Configuration: Hashable {
    public enum Image: Hashable {
      case image(UIImage?)
      case asyncImage(URL?, ImageDownloadTask)
      
      public func hash(into hasher: inout Hasher) {
        switch self {
        case .image(let image):
          hasher.combine(image)
        case .asyncImage(let url, _):
          hasher.combine(url)
        }
      }
      
      public static func ==(lhs: Image, rhs: Image) -> Bool {
        switch (lhs, rhs) {
        case (.image(let lImage), .image(let rImage)):
          return lImage == rImage
        case (.asyncImage(let lUrl, _), .asyncImage(let rUrl, _)):
          return lUrl == rUrl
        default:
          return false
        }
      }
    }
    public let image: Image
    public let tintColor: UIColor
    public let backgroundColor: UIColor
    public let size: CGSize
    public let cornerRadius: CGFloat
    public let contentMode: UIImageView.ContentMode
    public let imageSize: CGSize
    
    public init(image: Image,
                tintColor: UIColor,
                backgroundColor: UIColor,
                size: CGSize,
                cornerRadius: CGFloat,
                contentMode: UIImageView.ContentMode = .center,
                imageSize: CGSize? = nil) {
      self.image = image
      self.tintColor = tintColor
      self.backgroundColor = backgroundColor
      self.size = size
      self.cornerRadius = cornerRadius
      self.contentMode = contentMode
      self.imageSize = imageSize ?? size
    }
  }
  
  public func configure(configuration: Configuration) {
    switch configuration.image {
    case .image(let image):
      imageView.image = image
    case .asyncImage(_, let imageDownloadTask):
      imageDownloadTask.start(imageView: imageView, size: configuration.size, cornerRadius: configuration.cornerRadius)
      self.imageDownloadTask = imageDownloadTask
    }
    imageView.tintColor = configuration.tintColor
    imageView.tintAdjustmentMode = .normal
    backgroundColor = configuration.backgroundColor
    size = configuration.size
    cornerRadius = configuration.cornerRadius
    layer.cornerRadius = configuration.cornerRadius
    imageView.contentMode = configuration.contentMode
    imageSize = configuration.imageSize
    
    setNeedsLayout()
  }
}

private extension TKUIListItemImageIconView {
  func setup() {
    layer.masksToBounds = true
    imageView.contentMode = .center
    addSubview(imageView)
  }
}

extension CGSize: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(width)
    hasher.combine(height)
  }
}
