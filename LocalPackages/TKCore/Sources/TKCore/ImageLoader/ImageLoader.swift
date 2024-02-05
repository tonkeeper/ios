import Kingfisher
import UIKit

public final class ImageLoader {
  public init() {}
  
  
  public func loadImage(url: URL?,
                        imageView: UIImageView,
                        size: CGSize? = nil,
                        cornerRadius: CGFloat? = nil) -> DownloadTask? {
    var options = KingfisherOptionsInfo()
    var processor: ImageProcessor = DefaultImageProcessor.default
    
    options.append(.keepCurrentImageWhileLoading)
    options.append(.loadDiskFileSynchronously)
    options.append(.memoryCacheExpiration(.expired))
    
    if let size = size {
      processor = processor |> DownsamplingImageProcessor(size: size)
      options.append(.scaleFactor(UIScreen.main.scale))
    }
    if let cornerRadius = cornerRadius {
      processor = processor |> RoundCornerImageProcessor(cornerRadius: cornerRadius)
    }
    
    options.append(.processor(processor))
    
    return imageView.kf.setImage(with: url, options: options)
  }
}
