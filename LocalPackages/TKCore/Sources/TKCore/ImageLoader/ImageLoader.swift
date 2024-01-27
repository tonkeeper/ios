import Kingfisher
import UIKit

public final class ImageLoader {
  public init() {}
  
  public func loadImage(url: URL,
                        imageView: UIImageView,
                        size: CGSize? = nil,
                        cornerRadius: CGFloat? = nil) {
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
    
    imageView.kf.setImage(with: url, options: options)
  }
  
  @MainActor
  public func loadImage(url: URL?,
                        imageView: UIImageView,
                        size: CGSize? = nil,
                        cornerRadius: CGFloat? = nil) async throws {
    var processor: ImageProcessor = DefaultImageProcessor.default
    var scaleFactor: CGFloat = 0
    if let size = size {
      processor = processor |> DownsamplingImageProcessor(size: size)
      scaleFactor = UIScreen.main.scale
    }
    if let cornerRadius = cornerRadius {
      processor = processor |> RoundCornerImageProcessor(cornerRadius: cornerRadius)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error> ) in
      KF.url(url)
        .setProcessor(processor)
        .scaleFactor(scaleFactor)
        .loadDiskFileSynchronously()
        .keepCurrentImageWhileLoading(true)
        .memoryCacheExpiration(.expired)
        .fade(duration: 0.25)
        .onSuccess { result in
          guard !Task.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
          }
          continuation.resume()
        }
        .onFailure { error in
          continuation.resume(throwing: error)
        }
        .set(to: imageView)
    }
  }
}
