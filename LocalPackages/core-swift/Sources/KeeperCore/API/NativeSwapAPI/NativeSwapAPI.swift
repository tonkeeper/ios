import Foundation
import TKLogging

public enum NativeSwapAPIError: Error, Decodable {
    case incorrectHost(String)
    case streamingFailed(message: String?)
    case serverError
}

protocol NativeSwapAPI {
    func fetchAssets(network: Network) async throws -> [SwapAsset]
    func subscribeToSwapConfirmation(data: SwapConfirmationData, network: Network) -> AsyncStream<Result<SwapConfirmation, NativeSwapAPIError>>
}

final class NativeSwapAPIImplementation: NativeSwapAPI {
    private let urlSession: URLSession
    private let configuration: Configuration
    private let decoder = JSONDecoder()
    private let logger = LogDomain.nativeSwapAPI

    init(
        urlSession: URLSession,
        configuration: Configuration
    ) {
        self.urlSession = urlSession
        self.configuration = configuration
    }

    func fetchAssets(network: Network) async throws -> [SwapAsset] {
        let url = configuration
            .swapHostURL(network: network)
            .appendingPathComponent("v2/swap/assets")

        logger.i("Fetching swap assets from: \(url.absoluteString)")

        do {
            let (data, _) = try await urlSession.data(from: url)
            let assets = try decoder.decode([SwapAsset].self, from: data)
            logger.i("Successfully fetched \(assets.count) swap assets")
            return assets
        } catch {
            logger.e("Failed to fetch swap assets: \(error.localizedDescription)")
            throw error
        }
    }

    func subscribeToSwapConfirmation(data: SwapConfirmationData, network: Network) -> AsyncStream<Result<SwapConfirmation, NativeSwapAPIError>> {
        logger.i("Subscribing to swap confirmation: \(data.fromAsset) → \(data.toAsset), amount: \(data.isSend ? data.fromAmount : data.toAmount), isSend: \(data.isSend)")

        // Create dedicated URLSession for this SSE stream for proper cancellation
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 300 // 5 minutes
        sessionConfig.timeoutIntervalForResource = 3600 // 1 hour
        let streamSession = URLSession(configuration: sessionConfig)

        return AsyncStream { (continuation: AsyncStream<Result<SwapConfirmation, NativeSwapAPIError>>.Continuation) in
            let task = Task { [weak self] in
                guard let self else {
                    self?.logger.d("Stream task deallocated before starting")
                    streamSession.invalidateAndCancel()
                    continuation.finish()
                    return
                }

                do {
                    let url = configuration
                        .swapHostURL(network: network)
                        .appendingPathComponent("v2/swap/omniston/stream")

                    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
                    var queryItems: [URLQueryItem] = [
                        URLQueryItem(name: "fromAsset", value: data.fromAsset),
                        URLQueryItem(name: "toAsset", value: data.toAsset),
                        URLQueryItem(name: "userAddress", value: data.userAddress),
                    ]

                    if data.isSend {
                        queryItems.append(URLQueryItem(name: "fromAmount", value: data.fromAmount))
                    } else {
                        queryItems.append(URLQueryItem(name: "toAmount", value: data.toAmount))
                    }

                    urlComponents?.queryItems = queryItems

                    guard let requestURL = urlComponents?.url else {
                        logger.e("Failed to construct request URL from: \(url.absoluteString)")
                        streamSession.invalidateAndCancel()
                        continuation.yield(
                            .failure(.incorrectHost(url.absoluteString))
                        )
                        return continuation.finish()
                    }

                    logger.d("Starting SSE stream: \(requestURL.absoluteString)")

                    var urlRequest = URLRequest(url: requestURL)
                    urlRequest.httpMethod = "GET"
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await streamSession.bytes(for: urlRequest)

                    if let httpResponse = response as? HTTPURLResponse {
                        logger.d("SSE stream connected with status: \(httpResponse.statusCode)")
                    }

                    var eventCount = 0

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else {
                            logger.d("Stream task cancelled, received \(eventCount) events")
                            streamSession.invalidateAndCancel()
                            continuation.finish()
                            return
                        }

                        guard line.hasPrefix("data: ") else { continue }

                        let jsonString = String(line.dropFirst(6))

                        // Skip connection confirmation events
                        if jsonString.contains("\"type\":\"connected\"") {
                            logger.d("SSE connection confirmed")
                            continue
                        }

                        // Handle error events
                        if jsonString.contains("\"error\":") {
                            logger.w("Server returned error event: \(jsonString)")
                            streamSession.invalidateAndCancel()
                            continuation.yield(
                                .failure(.serverError)
                            )
                            return continuation.finish()
                        }

                        // Decode swap confirmation
                        guard let jsonData = jsonString.data(using: .utf8) else {
                            logger.w("Failed to convert SSE data to UTF8")
                            continue
                        }

                        do {
                            let model = try self.decoder.decode(SwapConfirmation.self, from: jsonData)
                            eventCount += 1
                            logger.d("Received swap confirmation #\(eventCount): bidUnits=\(model.bidUnits), askUnits=\(model.askUnits)")
                            continuation.yield(.success(model))
                        } catch {
                            logger.w("Failed to decode swap confirmation: \(error.localizedDescription)")
                            continue
                        }
                    }

                    logger.i("SSE stream finished normally, received \(eventCount) events")
                    streamSession.invalidateAndCancel()
                    continuation.finish()
                } catch {
                    logger.w("SSE stream error: \(error.localizedDescription)")
                    streamSession.invalidateAndCancel()
                    continuation.yield(
                        .failure(.streamingFailed(message: error.localizedDescription))
                    )
                    return continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable [weak self] reason in
                self?.logger.d("Stream terminating, reason: \(String(describing: reason))")
                streamSession.invalidateAndCancel()
                task.cancel()
            }
        }
    }
}

private extension String {
    static let ipAPIHost = "https://swap.tonkeeper.com"
}

private extension Configuration {
    func swapHostURL(network: Network) -> URL {
        value(\.webSwapsUrl, network: network) ?? URL(string: .ipAPIHost)!
    }
}
