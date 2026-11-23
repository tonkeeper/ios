import Combine
import Foundation
import Kingfisher
import UIKit

public final class ImagePrefetcherService {
    public init() {}

    public func prefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            KingfisherManager.shared.retrieveImage(with: url, options: .prefetch) { _ in }
        }
    }

    /// Shares the cache entry and the in-flight download with `prefetch(urls:)`. A memory-cache hit
    /// completes synchronously; cancelling drops only this completion, not a shared download.
    public func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) -> AnyCancellable {
        let task = KingfisherManager.shared.retrieveImage(with: url, options: .prefetch) { result in
            completion(try? result.get().image)
        }
        return AnyCancellable { task?.cancel() }
    }
}

private extension KingfisherOptionsInfo {
    static let prefetch: KingfisherOptionsInfo = [.backgroundDecode]
}
