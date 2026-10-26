import Foundation
import TKLogging

struct TonConnectManifestLoader {
    private let urlSession: URLSession

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    func load(url: URL) async throws -> TonConnectManifest {
        let manifest = try await fetchManifest(url: url)
        guard manifest.url.host?.contains(".") == true else {
            throw TonConnectManifestError.invalidManifest
        }
        return manifest
    }
}

private extension TonConnectManifestLoader {
    func fetchManifest(url: URL) async throws -> TonConnectManifest {
        let urls = [url, url.proxyURL(noCache: true)].compactMap { $0 }

        for (index, fetchURL) in urls.enumerated() {
            do {
                let (data, _) = try await urlSession.data(from: fetchURL)
                return try JSONDecoder().decode(TonConnectManifest.self, from: data)
            } catch {
                guard index == urls.count - 1 else {
                    continue
                }
                throw mappedError(error, url: url)
            }
        }

        throw TonConnectManifestError.incorrectURL
    }

    func mappedError(_ error: Error, url: URL) -> TonConnectManifestError {
        let manifestError: TonConnectManifestError

        switch error {
        case is DecodingError:
            manifestError = .invalidManifest
        case let urlError as URLError where urlError.code == .badURL:
            manifestError = .incorrectURL
        default:
            manifestError = .loadFailed(error: error)
        }

        logManifestLoadingFailed(error: manifestError, url: url)
        return manifestError
    }

    func logManifestLoadingFailed(error: TonConnectManifestError, url: URL) {
        let errorDescription: String

        switch error {
        case .incorrectURL:
            errorDescription = "Incorrect URL"
        case .invalidManifest:
            errorDescription = "Invalid manifest"
        case let .loadFailed(error):
            errorDescription = error.localizedDescription
        }

        Log.e(
            "\(String(reflecting: TonConnectServiceImplementation.self)): manifest fetching failed",
            extraInfo: [
                "error": errorDescription,
                "url": url.absoluteString,
            ]
        )
    }
}
