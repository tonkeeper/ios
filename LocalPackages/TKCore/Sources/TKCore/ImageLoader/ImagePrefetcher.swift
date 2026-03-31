import Foundation
import Kingfisher

public final class ImagePrefetcherService {
    public init() {}

    public func prefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            KingfisherManager.shared.retrieveImage(with: url, options: [.backgroundDecode]) { _ in }
        }
    }
}
