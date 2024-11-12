import UIKit
import Kingfisher

public final class TKImageView: UIView, ConfigurableView {
  
  public struct Model: Hashable {
    public let image: TKImage?
    public let tintColor: UIColor?
    public let size: Size
    public let corners: Corners
    public let padding: UIEdgeInsets
    
    public init(image: TKImage?,
                tintColor: UIColor? = nil,
                size: Size = .auto,
                corners: Corners = .none,
                padding: UIEdgeInsets = .zero) {
      self.image = image
      self.tintColor = tintColor
      self.size = size
      self.corners = corners
      self.padding = padding
    }
  }
  
  public func configure(model: Model) {
    self.image = model.image
    self.size = model.size
    self.corners = model.corners
    self.padding = model.padding
    self.imageView.tintColor = model.tintColor
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  public enum Corners: Hashable {
    case none
    case circle
    case cornerRadius(cornerRadius: CGFloat)
  }
  
  public enum Size: Hashable {
    case none
    case auto
    case size(CGSize)
  }
  
  public var corners: Corners = .none {
    didSet {
      didUpdateCornerRadius()
    }
  }
  
  public var size: Size = .auto {
    didSet {
      didUpdateSize()
    }
  }
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      didUpdatePadding()
    }
  }
  
  public var image: TKImage? {
    didSet {
      didUpdateImage()
    }
  }
  
  public override var contentMode: UIView.ContentMode {
    get {
      imageView.contentMode
    }
    set {
      imageView.contentMode = newValue
    }
  }
  
  private let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()

    switch size {
    case .none:
      let imageViewFrame = CGRect(
        x: padding.left,
        y: padding.top,
        width: bounds.width - padding.left - padding.right,
        height: bounds.height - padding.top - padding.bottom
      )
      imageView.frame = imageViewFrame
    case .auto:
      let imageViewSizeThatFits = imageView.sizeThatFits(.zero)
      let imageViewFrame = CGRect(
        x: padding.left,
        y: padding.top,
        width: imageViewSizeThatFits.width,
        height: imageViewSizeThatFits.height
      )
      imageView.frame = imageViewFrame
    case .size(let size):
      let imageViewFrame = CGRect(
        x: padding.left,
        y: padding.top,
        width: size.width - padding.left - padding.right,
        height: size.height - padding.top - padding.bottom
      )
      imageView.frame = imageViewFrame
    }
    
    switch corners {
    case .none:
      layer.masksToBounds = false
      layer.cornerRadius = 0
    case .circle:
      layer.masksToBounds = true
      layer.cornerRadius = bounds.height/2
    case .cornerRadius(let cornerRadius):
      layer.masksToBounds = true
      layer.cornerRadius = cornerRadius
    }
    
    updateImage()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    switch self.size {
    case .none:
      return .zero
    case .auto:
      let imageViewSizeThatFits = imageView.sizeThatFits(.zero)
      let size = CGSize(width: imageViewSizeThatFits.width + padding.left + padding.right,
                        height: imageViewSizeThatFits.height + padding.top + padding.bottom)
      return size
    case .size(let size):
      let sizeThatFits = CGSize(
        width: size.width + padding.left + padding.right,
        height: size.height + padding.top + padding.bottom
      )
      return sizeThatFits
    }
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(.zero)
  }
  
  public func prepareForReuse() {
    image = nil
  }

  private func setup() {
    addSubview(imageView)
  }
  
  private func didUpdateImage() {
    updateImage()
  }
  
  private func didUpdateCornerRadius() {
    updateImage()
  }
  
  private func didUpdateSize() {
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  private func didUpdatePadding() {
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  private func updateImage() {
    switch image {
    case .image(let image):
      imageView.kf.cancelDownloadTask()
      imageView.image = image
    case .urlImage(let url):
      setImage(url: url)
    case .none:
      imageView.kf.cancelDownloadTask()
      imageView.image = nil
    }
  }
  
  private func setImage(url: URL?) {
    var options = KingfisherOptionsInfo()
    var processor: ImageProcessor = DefaultImageProcessor.default
    
    processor = processor |> DownsamplingImageProcessor(size: bounds.size)
    
    switch corners {
    case .none:
      break
    case .circle:
      processor = processor |> RoundCornerImageProcessor(
        cornerRadius: min(bounds.width, bounds.height)/2
      )
    case .cornerRadius(let cornerRadius):
      processor = processor |> RoundCornerImageProcessor(
        cornerRadius: cornerRadius
      )
    }
    
    options.append(.processor(processor))
    options.append(.scaleFactor(UIScreen.main.scale))
    
    imageView.kf.setImage(with: url, options: options)
  }
}
