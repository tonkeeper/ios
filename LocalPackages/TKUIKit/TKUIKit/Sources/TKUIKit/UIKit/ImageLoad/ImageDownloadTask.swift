import UIKit

public protocol ImageDownloadTask {
  func start(imageView: UIImageView,
             size: CGSize?,
             cornerRadius: CGFloat?)
  func cancel()
}
