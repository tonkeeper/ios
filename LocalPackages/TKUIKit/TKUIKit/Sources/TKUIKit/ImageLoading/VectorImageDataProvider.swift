import Foundation
import Kingfisher

public struct VectorImageDataProvider: ImageDataProvider {
    private static let maxByteCount = 1_000_000

    public let url: URL

    public var cacheKey: String {
        url.absoluteString
    }

    public init(url: URL) {
        self.url = url
    }

    public func data(handler: @escaping (Result<Data, Error>) -> Void) {
        let url = url
        Task {
            do {
                let bytes = try await Self.loadBytes(from: url)
                guard SVGDetection.looksLikeSVG(bytes) else {
                    handler(.success(bytes))
                    return
                }
                if let image = await SVGImageRasterizer.rasterize(svgData: bytes),
                   let png = image.pngData()
                {
                    handler(.success(png))
                } else {
                    handler(.failure(VectorImageProviderError.rasterizationFailed))
                }
            } catch {
                handler(.failure(error))
            }
        }
    }

    private static func loadBytes(from url: URL) async throws -> Data {
        if url.scheme?.lowercased() == "data" {
            guard let data = DataURIDecoder.decode(url) else {
                throw VectorImageProviderError.invalidDataURI
            }
            return data
        }
        // The icon URL is dapp-controlled, so bound the download instead of loading it whole.
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            // Otherwise an error page with an inline `<svg>` would be sniffed as the icon.
            throw VectorImageProviderError.badResponse
        }
        guard response.expectedContentLength <= Int64(maxByteCount) else {
            throw VectorImageProviderError.tooLarge
        }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxByteCount {
                throw VectorImageProviderError.tooLarge
            }
        }
        return data
    }
}

public enum VectorImageProviderError: Error {
    case invalidDataURI
    case rasterizationFailed
    case tooLarge
    case badResponse
}

/// `data:` and `.svg` URLs go straight to the vector provider (avoiding a fetch that would only
/// fail to decode); other URLs keep the network path with the provider as a decode fallback.
public struct DappIconSource {
    public let source: Source
    public let alternativeSources: [Source]

    public init(url: URL) {
        let provider = VectorImageDataProvider(url: url)
        if Self.isVectorLikely(url) {
            source = .provider(provider)
            alternativeSources = []
        } else {
            source = .network(url)
            alternativeSources = [.provider(provider)]
        }
    }

    public static func isVectorLikely(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "data" || url.pathExtension.lowercased() == "svg"
    }
}
