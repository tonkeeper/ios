import UIKit
import TKUIKit

public final class BuySellConfirmationImageView: UIView, ConfigurableView, ReusableView {
  
  private let imageView = UIImageView()
  
  private var size: CGSize = .zero
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
    imageView.frame = bounds
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    self.size
  }
  
  public func prepareForReuse() {
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    imageView.image = nil
  }

  public struct Model {
    public enum Image {
      case image(UIImage)
      case asyncImage(ImageDownloadTask)
    }
    public let image: Image
    public let tintColor: UIColor
    public let backgroundColor: UIColor
    public let size: CGSize
    
    public init(image: Image,
                tintColor: UIColor,
                backgroundColor: UIColor,
                size: CGSize) {
      self.image = image
      self.tintColor = tintColor
      self.backgroundColor = backgroundColor
      self.size = size
    }
  }
  
  public func configure(model: Model) {
    switch model.image {
    case .image(let image):
      imageView.image = image
    case .asyncImage(let imageDownloadTask):
      imageDownloadTask.start(imageView: imageView, size: model.size, cornerRadius: model.size.width/2)
      self.imageDownloadTask = imageDownloadTask
    }
    imageView.tintColor = model.tintColor
    backgroundColor = model.backgroundColor
    size = model.size
  }
}

private extension BuySellConfirmationImageView {
  func setup() {
    layer.masksToBounds = true
    
    imageView.contentMode = .scaleAspectFill
    addSubview(imageView)
  }
}
