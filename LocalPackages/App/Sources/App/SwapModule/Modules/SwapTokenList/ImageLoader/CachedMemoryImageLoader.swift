import Kingfisher
import UIKit

public final class CachedMemoryImageLoader {
  
  private static let cache: ImageCache = {
    let cache = ImageCache(name: "CachedMemoryImageLoader")
    cache.memoryStorage.config.countLimit = 50
    return cache
  }()
  
  private let memoryCacheExpiration: StorageExpiration
  
  public init(cacheExpirationInMinutes minutes: UInt) {
    let seconds = TimeInterval(minutes) * 60
    self.memoryCacheExpiration = .seconds(seconds)
  }
  
  public func loadImage(url: URL?,
                        imageView: UIImageView,
                        size: CGSize? = nil,
                        cornerRadius: CGFloat? = nil) -> Kingfisher.DownloadTask? {
    var options = KingfisherOptionsInfo()
    var processor: ImageProcessor = DefaultImageProcessor.default
    
    options.append(.keepCurrentImageWhileLoading)
    options.append(.loadDiskFileSynchronously)
    options.append(.targetCache(Self.cache))
    options.append(.memoryCacheExpiration(memoryCacheExpiration))
    options.append(.memoryCacheAccessExtendingExpiration(.cacheTime))
    
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
