import UIKit
import Kingfisher

public final class TKImageView: UIView, ConfigurableView {
  
  public struct Model: Hashable {
    public let image: TKImage?
    public let tintColor: UIColor?
    public let size: Size
    public let corners: Corners
    
    public init(image: TKImage?,
                tintColor: UIColor? = nil,
                size: Size = .auto,
                corners: Corners = .none) {
      self.image = image
      self.tintColor = tintColor
      self.size = size
      self.corners = corners
    }
  }
  
  public func configure(model: Model) {
    self.image = model.image
    self.size = model.size
    self.corners = model.corners
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
        x: 0,
        y: 0,
        width: bounds.width,
        height: bounds.height
      )
      imageView.frame = imageViewFrame
    case .auto:
      let imageViewSizeThatFits = imageView.sizeThatFits(.zero)
      let imageViewFrame = CGRect(
        x: bounds.width/2 - imageViewSizeThatFits.width/2,
        y: bounds.height/2 - imageViewSizeThatFits.height/2,
        width: imageViewSizeThatFits.width,
        height: imageViewSizeThatFits.height
      )
      imageView.frame = imageViewFrame
    case .size(let size):
      let imageViewFrame = CGRect(
        x: bounds.width/2 - size.width/2,
        y: bounds.height/2 - size.height/2,
        width: size.width,
        height: size.height
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
      let size = CGSize(width: imageViewSizeThatFits.width,
                        height: imageViewSizeThatFits.height)
      return size
    case .size(let size):
      let sizeThatFits = CGSize(
        width: size.width,
        height: size.height
      )
      return sizeThatFits
    }
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(.zero)
  }
  
  public func prepareForReuse() {
    image = .urlImage(nil)
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
