import Foundation
import TKLogging

struct TonConnectManifestLoader {
    private let urlSession: URLSession

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    func load(url: URL) async throws -> TonConnectManifest {
        guard let expectedOrigin = url.normalizedOrigin else {
            logManifestLoadingFailed(error: .invalidManifest, url: url)
            throw TonConnectManifestError.invalidManifest
        }

        let urls = [url, url.proxyURL].compactMap { $0 }

        for (index, fetchURL) in urls.enumerated() {
            let isLastURL = index == urls.count - 1

            do {
                let manifest = try await fetchManifest(url: fetchURL)
                guard manifest.url.normalizedOrigin == expectedOrigin else {
                    logManifestLoadingFailed(error: .invalidManifest, url: url)
                    throw TonConnectManifestError.invalidManifest
                }
                return manifest
            } catch let error as TonConnectManifestError {
                throw error
            } catch {
                guard isLastURL else {
                    continue
                }
                throw mappedError(error, url: url)
            }
        }

        throw TonConnectManifestError.incorrectURL
    }
}

private extension TonConnectManifestLoader {
    func fetchManifest(url: URL) async throws -> TonConnectManifest {
        let redirectBlocker = ManifestRedirectBlocker()

        do {
            let (data, response) = try await urlSession.data(
                for: URLRequest(url: url),
                delegate: redirectBlocker
            )
            guard !redirectBlocker.didReceiveRedirect,
                  !(response as? HTTPURLResponse).isRedirect
            else {
                throw TonConnectManifestError.invalidManifest
            }
            return try JSONDecoder().decode(TonConnectManifest.self, from: data)
        } catch {
            guard !redirectBlocker.didReceiveRedirect else {
                throw TonConnectManifestError.invalidManifest
            }
            throw error
        }
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

private extension Optional where Wrapped == HTTPURLResponse {
    var isRedirect: Bool {
        guard let statusCode = self?.statusCode else {
            return false
        }
        return (300 ..< 400).contains(statusCode)
    }
}

private final class ManifestRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var receivedRedirect = false

    var didReceiveRedirect: Bool {
        lock.lock()
        defer { lock.unlock() }
        return receivedRedirect
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        receivedRedirect = true
        lock.unlock()
        completionHandler(nil)
    }
}
