import Kingfisher
import UIKit
import TKUIKit

public final class ImageLoader {
  public init() {}
  
  public func loadImage(url: URL?,
                        imageView: UIImageView,
                        size: CGSize? = nil,
                        cornerRadius: CGFloat? = nil) -> Kingfisher.DownloadTask? {
    var options = KingfisherOptionsInfo()
    var processor: ImageProcessor = DefaultImageProcessor.default

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

public class ImageDownloadTask: TKUIKit.ImageDownloadTask {
  let closure: (UIImageView, CGSize?, CGFloat?) -> Kingfisher.DownloadTask?
  var downloadTask: Kingfisher.DownloadTask?
  
  public init(closure: @escaping (UIImageView, CGSize?, CGFloat?) -> Kingfisher.DownloadTask?) {
    self.closure = closure
  }
  
  public func start(imageView: UIImageView,
             size: CGSize? = nil,
             cornerRadius: CGFloat? = nil) {
    self.downloadTask = closure(imageView, size, cornerRadius)
  }
  
  public func cancel() {
    self.downloadTask?.cancel()
  }
}
