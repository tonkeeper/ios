import Foundation
import TKLogging

@frozen public enum NativeSwapAPIError: Error, Decodable {
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

        return AsyncStream { (continuation: AsyncStream<Result<SwapConfirmation, NativeSwapAPIError>>.Continuation) in
            let session = NativeSwapSseSession(
                network: network,
                data: data,
                configuration: configuration
            )
            Task {
                await session.start(
                    output: NativeSwapSseSessionOutput(
                        emit: { model in
                            continuation.yield(.success(model))
                        },
                        finalize: { result in
                            switch result {
                            case .success:
                                continuation.finish()
                            case let .failure(error):
                                continuation.yield(.failure(error))
                                continuation.finish()
                            }
                        }
                    )
                )
            }
            continuation.onTermination = { @Sendable [weak session] reason in
                guard let session else {
                    return
                }
                Log.nativeSwapAPI.d("Stream terminating, reason: \(String(describing: reason))")
                Task {
                    await session.cancel()
                }
            }
        }
    }
}

private extension String {
    static let ipAPIHost = "https://swap.tonkeeper.com"
}

extension Configuration {
    func swapHostURL(network: Network) -> URL {
        value(\.webSwapsUrl, network: network) ?? URL(string: .ipAPIHost)!
    }
}
